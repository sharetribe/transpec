# coding: utf-8

require 'spec_helper'
require 'transpec/context'

module Transpec
  describe Context do
    include ::AST::Sexp
    include_context 'parsed objects'

    def node_id(node)
      id = node.type.to_s
      node.children.each do |child|
        break if child.is_a?(Parser::AST::Node)
        id << " #{child.inspect}"
      end
      id
    end

    describe '#scopes' do
      let(:source) do
        <<-END
          top_level

          RSpec.configure do |config|
            config.before do
              in_hook
            end
          end

          module SomeModule
            in_module

            describe 'something' do
              def some_method(some_arg)
                do_something
              end

              it 'is 1' do
                in_example
              end
            end

            1.times do
              in_normal_block
            end
          end
        END
      end

      it 'returns scope stack' do
        AST::Scanner.scan(ast) do |node, ancestor_nodes|
          expected_scopes = begin
            case node_id(node)
            when 'send nil :top_level'
              []
            when 'send nil :in_hook'
              [:rspec_configure, :hook]
            when 'module'
              []
            when 'const nil :SomeModule'
              # [:module] # TODO
            when 'send nil :in_module'
              [:module]
            when 'send nil :describe'
              # [:module] # TODO
            when 'def :some_method'
              [:module, :example_group]
            when 'arg :some_arg'
              # [:module, :example_group] # TODO
            when 'send nil :do_something'
              [:module, :example_group, :def]
            when 'send nil :it'
              # [:module, :example_group] # TODO
            when 'str "is 1"'
              # [:module, :example_group] # TODO
            when 'send nil :in_example'
              [:module, :example_group, :example]
            when 'send nil :in_normal_block'
              [:module]
            end
          end

          # TODO: Some scope nodes have special child nodes
          #   such as their arguments or their subject.
          #   But from scope point of view, the child nodes are not in the parent's scope,
          #   they should be in the next outer scope.

          next unless expected_scopes

          context_object = Context.new(ancestor_nodes)
          context_object.scopes.should == expected_scopes
        end
      end
    end

    describe '#in_example_group?' do
      include_context 'isolated environment'

      let(:context_object) do
        AST::Scanner.scan(ast) do |node, ancestor_nodes|
          next unless node == s(:send, nil, :target)
          return Context.new(ancestor_nodes)
        end

        fail 'Target node not found!'
      end

      subject { context_object.in_example_group? }

      shared_examples 'returns expected value' do
        let(:self_class_name_in_context) do
          result_path = 'result.txt'

          helper_source = <<-END
            def target
              File.write(#{result_path.inspect}, self.class.name)
            end
          END

          source_path = 'context_spec.rb'
          File.write(source_path, helper_source + source)

          `rspec #{source_path}`

          File.read(result_path)
        end

        let(:expected) do
          self_class_name_in_context.start_with?('RSpec::Core::ExampleGroup::')
        end

        it { should == expected }
      end

      context 'when in top level' do
        let(:source) do
          'target'
        end

        include_examples 'returns expected value'
      end

      context 'when in an instance method in top level' do
        let(:source) do
          <<-END
            def some_method
              target
            end

            describe('test') { example { target } }
          END
        end

        include_examples 'returns expected value'
      end

      context 'when in a block in an instance method in top level' do
        let(:source) do
          <<-END
            def some_method
              1.times do
                target
              end
            end

            describe('test') { example { target } }
          END
        end

        include_examples 'returns expected value'
      end

      context 'when in #describe block in top level' do
        let(:source) do
          <<-END
            describe 'foo' do
              target
            end
          END
        end

        include_examples 'returns expected value'
      end

      context 'when in an instance method in #describe block in top level' do
        let(:source) do
          <<-END
            describe 'foo' do
              def some_method
                target
              end

              example { some_method }
            end
          END
        end

        include_examples 'returns expected value'
      end

      context 'when in #it block in #describe block in top level' do
        let(:source) do
          <<-END
            describe 'foo' do
              it 'is an example' do
                target
              end
            end
          END
        end

        include_examples 'returns expected value'
      end

      context 'when in #before block in #describe block in top level' do
        let(:source) do
          <<-END
            describe 'foo' do
              before do
                target
              end

              example { }
            end
          END
        end

        include_examples 'returns expected value'
      end

      context 'when in #before(:each) block in #describe block in top level' do
        let(:source) do
          <<-END
            describe 'foo' do
              before(:each) do
                target
              end

              example { }
            end
          END
        end

        include_examples 'returns expected value'
      end

      context 'when in #before(:all) block in #describe block in top level' do
        let(:source) do
          <<-END
            describe 'foo' do
              before(:all) do
                target
              end

              example { }
            end
          END
        end

        include_examples 'returns expected value'
      end

      context 'when in #after block in #describe block in top level' do
        let(:source) do
          <<-END
            describe 'foo' do
              after do
                target
              end

              example { }
            end
          END
        end

        include_examples 'returns expected value'
      end

      context 'when in #after(:each) block in #describe block in top level' do
        let(:source) do
          <<-END
            describe 'foo' do
              after(:each) do
                target
              end

              example { }
            end
          END
        end

        include_examples 'returns expected value'
      end

      context 'when in #after(:all) block in #describe block in top level' do
        let(:source) do
          <<-END
            describe 'foo' do
              after(:all) do
                target
              end

              example { }
            end
          END
        end

        include_examples 'returns expected value'
      end

      context 'when in #around block in #describe block in top level' do
        let(:source) do
          <<-END
            describe 'foo' do
              around do
                target
              end

              example { }
            end
          END
        end

        include_examples 'returns expected value'
      end

      context 'when in #subject block in #describe block in top level' do
        let(:source) do
          <<-END
            describe 'foo' do
              subject do
                target
              end

              example { subject }
            end
          END
        end

        include_examples 'returns expected value'
      end

      context 'when in #subject! block in #describe block in top level' do
        let(:source) do
          <<-END
            describe 'foo' do
              subject! do
                target
              end

              example { subject }
            end
          END
        end

        include_examples 'returns expected value'
      end

      context 'when in #let block in #describe block in top level' do
        let(:source) do
          <<-END
            describe 'foo' do
              let(:something) do
                target
              end

              example { something }
            end
          END
        end

        include_examples 'returns expected value'
      end

      context 'when in #let! block in #describe block in top level' do
        let(:source) do
          <<-END
            describe 'foo' do
              let!(:something) do
                target
              end

              example { something }
            end
          END
        end

        include_examples 'returns expected value'
      end

      context 'when in any other block in #describe block in top level' do
        let(:source) do
          <<-END
            describe 'foo' do
              1.times do
                target
              end

              example { }
            end
          END
        end

        include_examples 'returns expected value'
      end

      context 'when in a class in a block in #describe block' do
         let(:source) do
          <<-END
            describe 'foo' do
              it 'is an example' do
                class SomeClass
                  target
                end
              end
            end
          END
        end

        include_examples 'returns expected value'
      end

      context 'when in an instance method in a class in a block in #describe block' do
         let(:source) do
          <<-END
            describe 'foo' do
              it 'is an example' do
                class SomeClass
                  def some_method
                    target
                  end
                end

                SomeClass.new.some_method
              end
            end
          END
        end

        include_examples 'returns expected value'
      end

      context 'when in #describe block in a module' do
        let(:source) do
          <<-END
            module SomeModule
              describe 'foo' do
                target
              end
            end
          END
        end

        include_examples 'returns expected value'
      end

      context 'when in an instance method in #describe block in a module' do
        let(:source) do
          <<-END
            module SomeModule
              describe 'foo' do
                def some_method
                  target
                end

                example { some_method }
              end
            end
          END
        end

        include_examples 'returns expected value'
      end

      context 'when in a block in #describe block in a module' do
        let(:source) do
          <<-END
            module SomeModule
              describe 'foo' do
                it 'is an example' do
                  target
                end
              end
            end
          END
        end

        include_examples 'returns expected value'
      end

      context 'when in an instance method in a module' do
        let(:source) do
          <<-END
            module SomeModule
              def some_method
                target
              end
            end

            describe 'test' do
              include SomeModule
              example { some_method }
            end
          END
        end

        # Instance methods of module can be used by `include SomeModule` in #describe block.
        include_examples 'returns expected value'
      end

      context 'when in an instance method in a class' do
        let(:source) do
          <<-END
            class SomeClass
              def some_method
                target
              end
            end

            describe 'test' do
              example { SomeClass.new.some_method }
            end
          END
        end

        include_examples 'returns expected value'
      end

      context 'when in RSpec.configure' do
        let(:source) do
          <<-END
            RSpec.configure do |config|
              target
            end
          END
        end

        include_examples 'returns expected value'
      end

      context 'when in #before block in RSpec.configure' do
        let(:source) do
          <<-END
            RSpec.configure do |config|
              config.before do
                target
              end
            end

            describe('test') { example { } }
          END
        end

        include_examples 'returns expected value'
      end

      context 'when in a normal block in RSpec.configure' do
        let(:source) do
          <<-END
            RSpec.configure do |config|
              1.times do
                target
              end
            end
          END
        end

        include_examples 'returns expected value'
      end

      context 'when in an instance method in RSpec.configure' do
        let(:source) do
          <<-END
            RSpec.configure do |config|
              def some_method
                target
              end
            end

            describe('test') { example { some_method } }
          END
        end

        include_examples 'returns expected value'
      end
    end
  end
end
