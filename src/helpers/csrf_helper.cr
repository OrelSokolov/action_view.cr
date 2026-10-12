# CsrfHelper — csrf_meta_tags, порт actionview 8.1.4
# lib/action_view/helpers/csrf_helper.rb.
#
# В plain view-контекстах (без forgery-слоя) возвращает "" — как
# Rails при protect_against_forgery? false. Контроллер с
# protect_from_forgery переопределяет __csrf_meta_token и отдаёт
# глобальный токен для XHR-флоу.

module ActionView
  module Helpers
    module CsrfHelper
      # Overridden by RequestForgeryProtection ( ActionController::Base).
      protected def __csrf_param_name : String
        "authenticity_token"
      end

      # Overridden by RequestForgeryProtection; nil — no meta tags.
      protected def __csrf_meta_token : String?
        nil
      end

      def csrf_meta_tags : SafeString
        if token = __csrf_meta_token
          SafeString.new(String.build do |io|
            io << %(<meta name="csrf-param" content="#{__csrf_param_name}" />\n)
            io << %(<meta name="csrf-token" content="#{token}" />)
          end)
        else
          SafeString.new("")
        end
      end
    end
  end
end
