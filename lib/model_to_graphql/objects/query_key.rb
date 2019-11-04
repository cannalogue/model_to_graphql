# frozen_string_literal: true

module ModelToGraphql
  module Objects
    module QueryKey
      def self.[](model)
        case model
        when String, Symbol
          "#{self.name}::#{normalize_name(model)}".constantize
        else
          "#{self.name}::#{normalize_name(model.name)}".constantize
        end
      end

      def self.const_missing(name)
        query_key_enum        = ModelToGraphql::Objects::Helper.make_query_key_enum(denormalize(name))
        actual_return_type    = GraphQL::Schema::List.new(GraphQL::Schema::NonNull.new(query_key_enum))
        actual_resolver_class = Class.new(GraphQL::Schema::Resolver) do
          @@query_key_type = query_key_enum
          type(actual_return_type, null: false)
          def resolve
            @@query_key_type.map { |f| f.values.keys }
          end
        end
        self.const_set(name, actual_resolver_class)
      end

      def self.remove_all_constants
        self.constants.each do |c|
          self.send(:remove_const, c)
        end
      end

      def self.normalize_name(name)
        name.to_s.gsub("::", "__")
      end

      def self.denormalize(name)
        name.to_s.gsub("__", "::")
      end
    end
  end
end