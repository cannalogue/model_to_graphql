# frozen_string_literal: true

module ModelToGraphql
  module Objects
    module RecordResolver
      def self.[](model)
        case model
        when String, Symbol
          "#{self.name}::#{normalize_name(model)}".constantize
        else
          "#{self.name}::#{normalize_name(model.name)}".constantize
        end
      end

      def self.const_missing(name)
        record_resolver = ModelToGraphql::Objects::Helper.make_record_resolver(denormalize(name))
        self.const_set(name, record_resolver)
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