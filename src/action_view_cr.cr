require "attr_reader_cr"
require "erb_cr"
require "active_support_cr"
# action_view.cr — порт ActionView (хелперы, шаблоны, FormBuilder).
#
# ERB-компиляция и output-safety — в шарде erb_cr (ERB::Rendering,
# ERB::SafeString): `<%= %>` экранирует (кроме SafeString), блочные
# хелперы работают через общий буфер вывода.

require "./output_safety"
require "./helpers/tag_helper"
require "./helpers/text_helper"
require "./helpers/url_helper"
require "./helpers/asset_tag_helper"
require "./helpers/embed_file_helper"
require "./helpers/form_options_helper"
require "./helpers/form_tag_helper"
require "./helpers/form_helper"
require "./helpers/cache_helper"
require "./helpers/csrf_helper"
require "./helpers/vite_helper"
require "./helpers/record_identifier"

module ActionView
  VERSION = "0.1.0"

  # ERB-слой живёт в erb_cr; алиас держит ActionView::SafeString тем же
  # типом, что ERB::SafeString (используется хелперами и action_pack'ом).
  alias SafeString = ERB::SafeString

  module Helpers
    include ERB::Rendering

    # ECR does not escape `<%= %>` output in hand-written legacy
    # templates; compiled templates auto-escape via __erb_esc instead.
    def h(value) : String
      HTML.escape(value.to_s)
    end

    include TagHelper
    include TextHelper
    include NumberHelper
    include UrlHelper
    include AssetTagHelper
    include EmbedFileHelper
    include FormTagHelper
    include FormOptionsHelper
    include FormHelper
    include CacheHelper
    include CsrfHelper
    include ViteHelper
    include RecordIdentifier
  end
end
