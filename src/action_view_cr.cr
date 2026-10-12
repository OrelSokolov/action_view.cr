require "html"
# action_view.cr — порт ActionView (хелперы, шаблоны, FormBuilder).
#
# ERB-синтаксис компилируется в методы-рендеры на этапе сборки с
# семантикой Rails: `<%= %>` экранирует (кроме SafeString), блочные
# хелперы работают через общий буфер вывода.

require "active_support_cr"
require "./output_safety"
require "./rendering"
require "./helpers/tag_helper"
require "./helpers/text_helper"
require "./helpers/url_helper"
require "./helpers/asset_tag_helper"
require "./helpers/embed_file_helper"
require "./helpers/form_tag_helper"
require "./helpers/form_helper"
require "./helpers/cache_helper"
require "./helpers/csrf_helper"
require "./helpers/vite_helper"
require "./helpers/record_identifier"

module ActionView
  VERSION = "0.1.0"

  module Helpers
    include ActionView::Rendering

    # ECR does not escape `<%= %>` output in hand-written legacy
    # templates; compiled templates auto-escape via __av_esc instead.
    def h(value) : String
      HTML.escape(value.to_s)
    end

    def html_escape(value : String) : String
      HTML.escape(value)
    end

    include TagHelper
    include TextHelper
    include NumberHelper
    include UrlHelper
    include AssetTagHelper
    include EmbedFileHelper
    include FormTagHelper
    include FormHelper
    include CacheHelper
    include CsrfHelper
    include ViteHelper
    include RecordIdentifier
  end
end
