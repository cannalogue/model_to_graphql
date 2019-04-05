# frozen_string_literal: true

require_relative "../loaders/record_loader.rb"

module ModelToGraphql
  module Generators

    unless defined?(GraphQL::Schema::Resolver)
      raise "Graphql is not loaded!!!"
    end

    class SingleRecordQueryGenerator < GraphQL::Schema::Resolver

      argument :id, ID, required: true

      def resolve(id: nil)
        ModelToGraphql::Loaders::RecordLoader.for(klass).load(id)
      end

      def klass
        self.class.klass
      end

      def self.to_query_resolver(klass, return_type)
        Class.new(SingleRecordQueryGenerator) do
          type return_type, null: true
          for_class klass
        end
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
