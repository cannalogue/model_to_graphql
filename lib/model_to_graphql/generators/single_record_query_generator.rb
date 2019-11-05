# frozen_string_literal: true

module ModelToGraphql
  module Generators
    class SingleRecordQueryGenerator < GraphQL::Schema::Resolver

      argument :id, ID, required: true

      def resolve(path: [], lookahead: nil, id: nil)
        ModelToGraphql::Loaders::RecordLoader.for(klass).load(id)
      end

      def klass
        self.class.klass
      end

      def self.build(klass, return_type)
        ModelToGraphql.logger.debug "ModelToGQL | Generating single record resolver #{klass.name} ..."
        query_klass = Class.new(SingleRecordQueryGenerator) do
          type return_type, null: true
          for_class klass
        end
        query_klass
      end

      def self.for_class(klass)
        @klass = klass
      end

      def self.klass
        @klass
      end

      def self.inspect
        "#<Single#{klass}Resolver>"
      end
    end
  end
end
