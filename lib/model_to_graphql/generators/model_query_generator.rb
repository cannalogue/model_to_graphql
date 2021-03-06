# frozen_string_literal: true

module ModelToGraphql
  module Generators
    class ModelQueryGenerator < GraphQL::Schema::Resolver
      argument :unscope, Boolean, required: false, default_value: false

      argument :page, Integer, required: false, default_value: 1,  prepare: -> (page, _ctx) {
        if page && page >= 99999999
          raise GraphQL::ExecutionError, "page is too big!"
        else
          page
        end
      }

      argument :per,  Integer, required: false, default_value: 10, prepare: -> (per, _ctx) {
        if per && per > 100
          raise GraphQL::ExecutionError, "not allowed to return more than 100 items in one page!"
        else
          per
        end
      }

      def authorized?(*args)
        return true if !object.nil?
        guard_proc = ModelToGraphql.config_options[:authorize_action]
        if !guard_proc.nil? && guard_proc.is_a?(Proc)
          return guard_proc.call(object, args[0], context, :query_model, self.class.model_class)
        end
        true
      end

      # @params filter [Hash]
      def resolve(path: [], lookahead: nil, filter: {}, unscope: false, **args)
        func = proc {
          scope = default_scope(path&.last&.underscore)
          filter.each do |arg, value|
            arg_handler = self.class.query_handlers[arg.to_s]
            if !arg_handler.nil?
              scope = arg_handler.call(scope, value)
            end
          end
          scope = pagination(scope, **args)
          scope = sort(scope, **args)
        }

        result_scope = if unscope
                        self.class.model_class.unscoped(&func)
                      else
                        func.call
                      end

        OpenStruct.new(
          list:  result_scope,
          total: 0,
          page:  args[:page]
        )
      end

      def pagination(scope, page:, per:, **kwargs)
        scope.page(page).per(per)
      end

      def sort(scope, sort: nil, **kwargs)
        return scope if sort.nil?
        if sort.end_with? "_desc"
          scope.order_by("#{sort[0..-6]}": :desc)
        else
          scope.order_by("#{sort[0..-5]}": :asc)
        end
      end

      def default_scope(relation_name)
        authorized_scope = self.class.resolve_authorized_scope(context, self.class.model_class)
        if !object.nil? && relation_name && has_relation(object, relation_name)
          base_selector     = authorized_scope.selector
          relation_selector = object.send(relation_name).selector
          self.class.model_class.where(base_selector).and(relation_selector)
        else
          authorized_scope
        end
      end

      def has_relation(object, path)
        !object.class.relations[path.to_s].nil?
      end

      # Generate graphql field resolver class
      # @param model Base model class
      # @param return_type The corresponding graphql type of the given model class
      # @param query_type The filter type
      # @param sort_key_enum Suppotted sort keys
      def self.build(model, return_type, query_type, sort_key_enum)
        ModelToGraphql.logger.debug "ModelToGQL | Generating model query resolver #{model.name} ..."
        Class.new(ModelQueryGenerator) do
          type(ModelToGraphql::Objects::PagedResult[return_type], null: false)
          to_resolve(model, query_type)
          argument(:sort, sort_key_enum, required: false)
        end
      end

      def self.to_resolve(model, query_type)
        @model_klass = model
        argument(:filter, query_type, required: false)
        @handlers = query_type.argument_hanlders
      end

      def self.model_class
        @model_klass
      end

      def self.query_handlers
        @handlers || {}
      end

      # Resovle the authorized scope
      # @param context Graphql execution context
      # @param model Base model class
      def self.resolve_authorized_scope(context, model)
        scope_resolver = ModelToGraphql.config_options[:list_scope]
        return model if scope_resolver.nil?
        begin
          return scope_resolver.call(context, model)
        rescue => e
          ModelToGraphql.logger.error "Failed to resolve the scope for #{model} when the context is #{context}"
          raise e
        end
      end

      def self.inspect
        "#<Query#{model_class}Resolver>"
      end
    end
  end
end
