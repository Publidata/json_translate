module JSONTranslate
  module Translates
    module InstanceMethods
      def disable_fallback
        toggle_fallback(false)
        yield if block_given?
      end

      def enable_fallback
        toggle_fallback(true)
        yield if block_given?
      end

      protected

      attr_reader :enabled_fallback

      def json_translate_fallback_locales(locale)
        short_locale = locale.to_s[0..1].to_sym
        if enabled_fallback != false && I18n.respond_to?(:fallbacks)
          Array(I18n.fallbacks[short_locale])
        else
          Array(short_locale)
        end
      end

      def read_json_translation(attr_name, locale = I18n.locale, fallback = true, **params)
        short_locale = locale.to_s[0..1].to_sym
        translations = public_send("#{attr_name}#{SUFFIX}") || {}

        selected_locale = short_locale
        if fallback
          selected_locale = json_translate_fallback_locales(short_locale).detect do |available_locale|
            translations[available_locale.to_s[0..1]].present?
          end
        end

        translation = translations[selected_locale.to_s]

        if translation && params.present?
          begin
            translation = I18n.interpolate(translation, params)
          rescue I18n::MissingInterpolationArgument
          end
        end

        translation
      end

      def write_json_translation(attr_name, value, locale = I18n.locale)
        short_locale = locale.to_s[0..1].to_sym
        value = value.presence
        translation_store = "#{attr_name}#{SUFFIX}"
        translations = public_send(translation_store) || {}
        public_send("#{translation_store}_will_change!") unless translations[short_locale.to_s] == value
        if value
          translations[short_locale.to_s] = value
        else
          translations.delete(short_locale.to_s)
        end
        public_send("#{translation_store}=", translations)
        value
      end

      def toggle_fallback(enabled)
        if block_given?
          old_value = @enabled_fallback
          begin
            @enabled_fallback = enabled
            yield
          ensure
            @enabled_fallback = old_value
          end
        else
          @enabled_fallback = enabled
        end
      end
    end
  end
end
