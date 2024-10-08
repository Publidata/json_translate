module JSONTranslate
  module Translates
    SUFFIX = "_translations".freeze
    MYSQL_ADAPTERS = %w[MySQL Mysql2 Mysql2Spatial]

    def translates(*attrs)
      include InstanceMethods

      class_attribute :translated_attribute_names, :permitted_translated_attributes

      self.translated_attribute_names = attrs
      self.permitted_translated_attributes = [
        *self.ancestors
          .select {|klass| klass.respond_to?(:permitted_translated_attributes) }
          .map(&:permitted_translated_attributes),
        *attrs.product(I18n.available_locales)
          .map { |attribute, locale| :"#{attribute}_#{locale.to_s[0..1]}" }
      ].flatten.compact

      attrs.each do |attr_name|
        define_method attr_name do |**params|
          read_json_translation(attr_name, params)
        end

        define_method "#{attr_name}=" do |value|
          write_json_translation(attr_name, value)
        end

        I18n.available_locales.each do |locale|
          short_locale = locale.to_s[0..1].to_sym
          normalized_locale = short_locale.to_s.downcase.gsub(/[^a-z]/, '')

          define_method :"#{attr_name}_#{normalized_locale}" do |**params|
            read_json_translation(attr_name, short_locale, false, params)
          end

          define_method "#{attr_name}_#{normalized_locale}=" do |value|
            write_json_translation(attr_name, value, short_locale)
          end
        end

        define_singleton_method "with_#{attr_name}_translation" do |value, locale = I18n.locale|
          short_locale = locale.to_s[0..1].to_sym

          quoted_translation_store = connection.quote_column_name("#{attr_name}#{SUFFIX}")
          translation_hash = { "#{short_locale}" => value }

          if MYSQL_ADAPTERS.include?(connection.adapter_name)
            where("JSON_CONTAINS(#{quoted_translation_store}, :translation, '$')", translation: translation_hash.to_json)
          else
            where("#{quoted_translation_store} @> :translation::jsonb", translation: translation_hash.to_json)
          end
        end

        define_singleton_method "order_by_#{attr_name}_translation" do |direction = :asc, locale = I18n.locale|
          short_locale = locale.to_s[0..1].to_sym
          quoted_translation_store = connection.quote_column_name("#{attr_name}#{SUFFIX}")

          if MYSQL_ADAPTERS.include?(connection.adapter_name)
            order(Arel.sql("JSON_EXTRACT(#{quoted_translation_store}, '$.\"#{short_locale}\"') #{direction}"))
          else
            order(Arel.sql("#{quoted_translation_store} ->> '#{short_locale}' #{direction}"))
          end
        end
      end
    end

    def translates?
      included_modules.include?(InstanceMethods)
    end
  end
end
