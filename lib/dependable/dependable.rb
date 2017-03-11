# Slayer Services are objects that should implement re-usable pieces of
# application logic or common tasks. To prevent circular dependencies Services
# are required to declare which other Service classes they depend on. If a
# circular dependency is detected an error is raised.
#
# In order to enforce the lack of circular dependencies, Service objects can
# only call other Services that are declared in their dependencies.
#
# @example Including Dependable on a base class
#   class Service
#     include Dependable
#     ...
#   end
#
#   class NetworkService < Service
#     ...
#   end
#
#   class StripeService < Service
#     dependencies NetworkService
#     ...
#   end
#
module Dependable
  def self.included(klass)
    klass.extend ClassMethods
  end

  # Everything in Dependable::ClassMethods automatically get extended onto the
  # class that includes Dependable.
  module ClassMethods
    attr_reader :deps

    # Declare the other Dependable classes that this class depends on. Only
    # dependencies that are included in this call my be invoked from class
    # or instances methods of this class.
    #
    # If no dependencies are provided, no other Service classes may be used by
    # this Service class.
    #
    # @param deps [Array<Class>] An array of the other Slayer::Service classes that are used as dependencies
    #
    # @example Calls with dependency declared
    #   class StripeService
    #     include Dependable
    #     dependencies NetworkService
    #
    #     def self.pay()
    #       ...
    #       NetworkService.post(url: "stripe.com", body: my_payload) # OK
    #       ...
    #     end
    #   end
    #
    # @example Calls without a dependency declared
    #   class JiraApiService
    #     include Dependable
    #
    #     def self.create_issue()
    #       ...
    #       NetworkService.post(url: "stripe.com", body: my_payload) # Raises Dependable::DependencyError
    #       ...
    #     end
    #   end
    #
    # @return [Array<Class>] The transitive closure of dependencies for this object.
    def dependencies(*deps)
      raise(DependencyError, "There were multiple \`dependencies\` definitions for #{self}.") if @deps

      deps.each do |dep|
        unless dep.is_a?(Class)
          raise(DependencyError, "The dependency \`#{dep}\` (for #{self}) was not a \`Class\` (was \`#{dep.class}\`).")
        end

        unless dep.ancestors.include?(Dependable)
          raise(DependencyError, "The dependency \`#{dep}\` (for #{self}) did not include \`Dependable\`.")
        end
      end

      unless deps.uniq.length == deps.length
        raise(DependencyError, "There were duplicate \`dependencies\` definitions for #{self}.")
      end

      @deps = deps

      # Calculate the transitive dependencies and raise an error if there are circular dependencies
      transitive_dependencies
    end

    def transitive_dependencies(dependency_hash = {}, visited = [])
      return @transitive_dependencies if @transitive_dependencies

      @deps ||= []

      # If we've already visited ourself, bail out. This is necessary to halt
      # execution for a circular chain of dependencies. #halting-problem-solved
      return dependency_hash[self] if visited.include?(self)

      visited << self
      dependency_hash[self] ||= []

      # Add each of our dependencies (and it's transitive dependency chain) to our
      # own dependencies.

      @deps.each do |dep|
        dependency_hash[self] << dep

        unless visited.include?(dep)
          child_transitive_dependencies = dep.transitive_dependencies(dependency_hash, visited)
          dependency_hash[self].concat(child_transitive_dependencies)
        end

        dependency_hash[self].uniq
      end

      # NO CIRCULAR DEPENDENCIES!
      if dependency_hash[self].include? self
        raise(DependencyError, "#{self} had a circular dependency.")
      end

      # Store these now, so next time we can short-circuit.
      @transitive_dependencies = dependency_hash[self]

      return @transitive_dependencies
    end

    # Dependency enforcement method hooks
    def hook_before_method(*)
      @deps ||= []
      @@allowed_services ||= nil

      # Confirm that this method call is allowed
      raise_if_not_allowed

      @@allowed_services ||= []
      @@allowed_services << (@deps + [self])
    end

    def hook_after_method(*)
      @@allowed_services.pop
      @@allowed_services = nil if @@allowed_services.empty?
    end

    def raise_if_not_allowed
      if @@allowed_services
        allowed = @@allowed_services.last

        if !(allowed && allowed.include?(self))
          raise(DependencyError, "Attempted to call #{self} from another \`#{Dependable}\` which did not declare it as a dependency.")
        end
      end
    end

    # Method hook infrastructure
    def singleton_method_added(name)
      insert_hooks_for(name,
      define_method_fn: :define_singleton_method,
      hook_target: self,
      # before_hook: hook_before_method,
      # after_hook: hook_after_method,
      alias_target: singleton_class)
    end

    def method_added(name)
      insert_hooks_for(name,
      define_method_fn: :define_method,
      hook_target: self,
      # before_hook: self.class.hook_before_method,
      # after_hook: self.class.hook_after_method,
      alias_target: self)
    end

    def insert_hooks_for(name, define_method_fn:, hook_target:, alias_target:)
      return if @__current_methods && @__current_methods.include?(name)

      with_hooks = :"__#{name}_with_hooks"
      without_hooks = :"__#{name}_without_hooks"

      @__current_methods = [name, with_hooks, without_hooks]
      send(define_method_fn, with_hooks) do |*args, &block|
        hook_target.send(:hook_before_method, name)
        begin
          send without_hooks, *args, &block
        rescue
          raise
        ensure
          hook_target.send(:hook_after_method, name)
        end
      end

      alias_target.send(:alias_method, without_hooks, name)
      alias_target.send(:alias_method, name, with_hooks)

      @__current_methods = nil
    end
  end
end
