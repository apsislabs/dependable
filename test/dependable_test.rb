require 'test_helper'

class DependableTest < Minitest::Test
  # Dependencies declarations
  def test_that_it_has_a_version_number
    refute_nil ::Dependable::VERSION
  end

  def test_include_adds_methods
    refute Class.new { }.respond_to?(:dependencies)
    assert Class.new { include Dependable }.respond_to?(:dependencies)
  end

  def test_ok_for_empty_dependencies
    Class.new { include Dependable; dependencies }
    Class.new { include Dependable; }
  end

  def test_raises_for_non_class_dependencies
    assert_raises Dependable::DependencyError do
      Class.new { include Dependable; dependencies(:b_service) }
    end
  end

  def test_raises_for_non_dependable_dependencies
    assert_raises Dependable::DependencyError do
      s = Class.new
      Class.new { include Dependable; dependencies(s) }
    end
  end

  def test_raises_for_multiple_calls_to_dependencies
    assert_raises Dependable::DependencyError do
      Class.new { include Dependable; dependencies; dependencies }
    end
  end

  def test_raises_error_for_duplicate_dependencies
    assert_raises Dependable::DependencyError do
      s = Class.new { include Dependable }
      Class.new { include Dependable; dependencies(s, s) }
    end
  end

  def test_subclasses_are_also_dependable
    s(:AService, proc { include Dependable }) do
      assert Class.new(AService).respond_to?(:dependencies)
    end
  end

  # Transitive dependency calculation
  def test_raises_error_for_circular_dependencies
    s(:FirstService, proc { include Dependable }) do
      s(:SecondService, proc { include Dependable }) do
        SecondService.dependencies FirstService

        assert_raises Dependable::DependencyError do
          FirstService.dependencies SecondService
        end
      end
    end
  end

  def test_transitive_dependency_chain
    s(:AService, proc { include Dependable }) do
      s(:BService, proc { include Dependable }) do
        s(:CService, proc { include Dependable }) do
          BService.dependencies AService
          CService.dependencies BService

          assert_array_contents_equal CService.transitive_dependencies, [BService, AService]
        end
      end
    end
  end

  # Dependency Enforcements
  def test_ok_for_instance_calls_from_outside_dependable
    s(:AService, proc { include Dependable; def return_3; 3; end }) do
      assert_equal AService.new.return_3, 3, 'AService instance should directly produce the result of 3'
    end
  end

  def test_ok_for_instance_calls_from_outside_dependable_inherited
    s(:DependableService, proc { include Dependable; }) do
      s(:AService, proc { def return_3; 3; end }, parent: DependableService) do
        assert_equal AService.new.return_3, 3, 'AService instance should directly produce the result of 3'
      end
    end
  end

  def test_ok_for_isntance_calls_from_inside_declared_dependency
    s(:AService, proc { include Dependable; def self.return_3; 3; end }) do
      s(:BService, proc { include Dependable; dependencies AService; def return_8; AService.return_3 + 5; end }) do
        assert_equal 8, BService.new.return_8
      end
    end
  end

  def test_ok_for_isntance_calls_from_inside_declared_dependency_inherited
    s(:DependableService, proc { include Dependable; }) do
      s(:AService, proc { def self.return_3; 3; end }, parent: DependableService) do
        s(:BService, proc { dependencies AService; def return_8; AService.return_3 + 5; end }, parent: DependableService) do
          assert_equal 8, BService.new.return_8
        end
      end
    end
  end

  def test_raises_for_call_to_dependable_not_in_dependencies
    s(:AService, proc { include Dependable; def self.return_3; 3; end }) do
      s(:BService, proc { include Dependable; def return_6; AService.return_3 + 3; end }) do
        assert_raises Dependable::DependencyError do
          BService.new.return_6
        end
      end
    end
  end

  def test_raises_for_call_to_dependable_not_in_dependencies_inherited
    s(:DependableService, proc { include Dependable; }) do
      s(:AService, proc { def self.return_3; 3; end }, parent: DependableService) do
        s(:BService, proc { def return_6; AService.return_3 + 3; end }, parent: DependableService) do
          assert_raises Dependable::DependencyError do
            BService.new.return_6
          end
        end
      end
    end
  end

  def test_ok_for_calls_to_self
    s(:AService, proc {
      include Dependable;
      def self.return_3; 3; end;
      def self.return_10; AService.return_3 + 7; end
    }) do
      assert_equal 10, AService.return_10
    end

  end
end
