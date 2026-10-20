# Synthetic oracle cases for ActionView P0/P1 (Iteration 3).
#
# Run against the ORIGINAL gem:
#   ruby oracle/cases.rb > oracle/expected.yml
#
# Each line: "<case_id>\t<rendered HTML>". The same case IDs are
# mirrored 1:1 in spec/oracle_spec.cr; the Crystal port must reproduce
# expected.yml exactly (captured from actionview 8.1.4).
#
# Block/output-buffer helpers (form_with, content_tag with block,
# content_for) are exercised through standalone inline ERB rendering,
# exactly like a real template would run them.
gem "actionview", "= 8.1.4"
require "action_view"
require "active_model"
require "active_support/cache/memory_store"
require "active_support/core_ext/date/calculations"

def render(v)
  case v
  when String then v
  when true, false, Integer, Float, nil then v.inspect
  else v.inspect
  end
end

def case_run(id)
  puts "#{id}\t#{render(yield)}"
rescue StandardError => e
  puts "#{id}\traise:#{e.class.name}"
end

# Standalone view: renders inline ERB templates the way a real request
# does (output buffer, capture, block helpers). CSRF protection is off
# (no controller/session here) — matches the CRails port, which has no
# CSRF layer yet; both sides generate identical tokenless forms.
class OracleView < ActionView::Base
  def protect_against_forgery?; false; end
end
VIEW = OracleView.with_empty_template_cache.new(ActionView::LookupContext.new([]), {}, nil)

# Plain helper context for direct (non-template) calls.
class Ctx
  include ActionView::Helpers
  def protect_against_forgery?; false; end
  def output_buffer; @output_buffer ||= nil; end
  attr_writer :output_buffer
end
CTX = Ctx.new

def tpl(src)
  VIEW.render(inline: src, formats: [:html]).strip
end

# Top-level delegation so case bodies can call helpers bare.
%w[
  escape_once raw safe_join content_tag tag
  pluralize truncate excerpt highlight word_wrap simple_format
  distance_of_time_in_words time_ago_in_words
  number_to_currency number_with_delimiter number_with_precision
  number_to_percentage number_to_human_size number_to_human number_to_phone
  link_to link_to_if link_to_unless mail_to button_to
  stylesheet_link_tag javascript_include_tag image_tag favicon_link_tag
  javascript_tag
  text_field_tag label_tag hidden_field_tag password_field_tag
  email_field_tag number_field_tag date_field_tag check_box_tag
  radio_button_tag text_area_tag search_field_tag telephone_field_tag
  url_field_tag color_field_tag range_field_tag submit_tag button_tag
  select_tag options_for_select
  file_field_tag time_field_tag datetime_field_tag datetime_local_field_tag
  month_field_tag week_field_tag phone_field_tag image_submit_tag
  options_from_collection_for_select grouped_options_for_select
  option_groups_from_collection_for_select
].each do |m|
  define_method(m) { |*a, **k, &b| CTX.public_send(m, *a, **k, &b) }
end

class PostModel
  include ActiveModel::Model
  attr_accessor :id, :title, :body, :published, :_destroy, :visits, :due,
                :author_id, :author_ids
  def self.model_name
    ActiveModel::Name.new(self, nil, "Post")
  end
  def to_param; id.to_s; end
  def persisted?; !id.nil?; end
end

# Parent with a nested-attributes association (mimics AR's
# accepts_nested_attributes_for :posts without pulling in ActiveRecord).
class UserModel
  include ActiveModel::Model
  attr_accessor :id, :name
  def self.model_name
    ActiveModel::Name.new(self, nil, "User")
  end
  def persisted?; !id.nil?; end
  def posts; @posts ||= []; end
  def posts_attributes=(records); end
end

# --- Output safety ------------------------------------------------
case_run("safe_html_safe")      { "<b>hi</b>".html_safe.html_safe? }
case_run("safe_plain_not")      { "<b>hi</b>".html_safe? }
case_run("safe_escape_once")    { escape_once("1 &gt; 2 & 3") }
case_run("safe_raw")            { raw("<b>x</b>") }
case_run("safe_raw_html_safe")  { raw("<b>x</b>").html_safe? }
case_run("safe_join")           { safe_join(["a", "<b>b</b>".html_safe, "c"], " | ") }
case_run("safe_join_escapes")   { safe_join(["<i>a</i>", "<b>b</b>".html_safe], ",") }
case_run("tpl_erb_escapes")     { tpl(%q{<%= "<script>x</script>" %>}) }
case_run("tpl_erb_raw_ok")      { tpl(%q{<%= raw "<b>ok</b>" %>}) }

# --- TagHelper ----------------------------------------------------
case_run("tag_br")              { tag("br") }
case_run("tag_img_src")         { tag("img", src: "x.png", alt: "Pic") }
case_run("tag_input_bool_true") { tag("input", type: "checkbox", checked: true) }
case_run("tag_input_bool_false"){ tag("input", type: "checkbox", checked: false) }
case_run("tag_nil_value")       { tag("img", src: nil, alt: "a") }
case_run("tag_data_nested")     { tag("div", data: {remote: "true", url: "/x"}) }
case_run("tag_aria_nested")     { tag("div", aria: {hidden: "true"}) }
case_run("tag_escape_values")   { tag("img", alt: %(a"b&<c)) }
case_run("tag_dot_form")        { tag.br }
case_run("tag_dot_attrs")       { tag.input type: "text", disabled: true }
case_run("ct_block")            { tpl(%q{<%= content_tag(:div, class: "wrap") { "inner" } %>}) }
case_run("ct_inline")           { content_tag(:p, "hello", class: "x") }
case_run("ct_nested")           { tpl(%q{<%= content_tag(:ul) { safe_join([content_tag(:li, "1"), content_tag(:li, "2")]) } %>}) }
case_run("ct_escapes")          { content_tag(:p, "<script>") }

# --- TextHelper ---------------------------------------------------
case_run("txt_pluralize_1")     { pluralize(1, "person") }
case_run("txt_pluralize_2")     { pluralize(2, "person") }
case_run("txt_pluralize_count") { pluralize(0, "person/plural") }
case_run("txt_truncate")        { truncate("The quick brown fox jumps over the lazy dog", length: 20) }
case_run("txt_truncate_sep")    { truncate("The quick brown fox jumps over the lazy dog", length: 20, separator: " ") }
case_run("txt_truncate_short")  { truncate("short", length: 20) }
case_run("txt_truncate_escape") { truncate("a<b>c" * 10, length: 12, escape: false) }
case_run("txt_excerpt")         { excerpt("This is an example", "an", radius: 3) }
case_run("txt_highlight")       { highlight("This is a beautiful morning", "beautiful") }
case_run("txt_highlight_multi") { highlight("a b c", ["a", "c"]) }
case_run("txt_word_wrap")       { word_wrap("one two three four five", line_width: 8) }
case_run("txt_simple_format")   { simple_format("a\n\nb\n c") }
case_run("txt_simple_escapes")  { simple_format("<b>a</b>") }
case_run("txt_cycle")           { tpl(%q{<%= cycle("a", "b") %><%= cycle("a", "b") %><%= cycle("a", "b") %>}) }
case_run("txt_current_cycle")   { tpl(%q{<% cycle("x", "y") %><%= current_cycle %>}) }
case_run("txt_reset_cycle")     { tpl(%q{<% cycle("x", "y") %><% reset_cycle %><%= cycle("x", "y") %>}) }
case_run("txt_dotw_words")      { distance_of_time_in_words(Time.utc(2026,1,1,12,0,0), Time.utc(2026,1,1,12,1,30)) }
case_run("txt_dotw_hours")      { distance_of_time_in_words(Time.utc(2026,1,1,12,0,0), Time.utc(2026,1,1,17,0,0)) }
case_run("txt_dotw_days")       { distance_of_time_in_words(Time.utc(2026,1,1), Time.utc(2026,1,9)) }
case_run("txt_dotw_about_mo")   { distance_of_time_in_words(Time.utc(2026,1,1), Time.utc(2026,2,3)) }
case_run("txt_dotw_seconds")    { distance_of_time_in_words(Time.utc(2026,1,1,12,0,0), Time.utc(2026,1,1,12,0,25), include_seconds: true) }

# --- NumberHelper (re-exported from ActiveSupport) ----------------
case_run("num_currency")        { number_to_currency(1234.5) }
case_run("num_delimiter")       { number_with_delimiter(1234567) }
case_run("num_precision")       { number_with_precision(3.14159, precision: 3) }
case_run("num_percentage")      { number_to_percentage(75.5) }
case_run("num_human_size")      { number_to_human_size(1048576) }
case_run("num_human")           { number_to_human(1_500_000) }
case_run("num_phone")           { number_to_phone(5551234567) }

# --- UrlHelper ----------------------------------------------------
case_run("url_link_plain")      { link_to("Home", "/") }
case_run("url_link_escapes")    { link_to(%q<a"b>, "/x?y=1") }
case_run("url_link_attrs")      { link_to("X", "/x", class: "btn", data: {turbo: "false"}) }
case_run("url_link_block")      { tpl(%q{<%= link_to "/x" do %>Big <b>link</b><% end %>}) }
case_run("url_link_if_true")    { link_to_if(true, "Y", "/y") }
case_run("url_link_if_false")   { link_to_if(false, "Y", "/y") { "(none)" } }
case_run("url_link_unless")     { link_to_unless(false, "Z", "/z") }
case_run("url_mail_to")         { mail_to("me@example.com", "Me") }
case_run("url_mail_to_emails")  { mail_to("me@example.com") }
case_run("url_button_to")       { button_to("Go", "/go") }
case_run("url_button_method")   { button_to("Del", "/d", method: :delete) }

# --- AssetTagHelper ----------------------------------------------
case_run("asset_css")           { stylesheet_link_tag("a", "b") }
case_run("asset_js")            { javascript_include_tag("a", "b") }
case_run("asset_image")         { image_tag("x.png", alt: "X") }
case_run("asset_image_size")    { image_tag("x.png", size: "40x50") }
case_run("asset_favicon")       { favicon_link_tag }
case_run("asset_js_tag")        { javascript_tag("alert(1)") }

# --- FormTagHelper -----------------------------------------------
case_run("ft_text_field")       { text_field_tag("name", "val", class: "i") }
case_run("ft_label")            { label_tag("name", "Name") }
case_run("ft_label_only")       { label_tag("name") }
case_run("ft_hidden")           { hidden_field_tag("token", "abc") }
case_run("ft_password")         { password_field_tag("pw") }
case_run("ft_email")            { email_field_tag("email", "a@b.c") }
case_run("ft_number")           { number_field_tag("n", 5, min: 0, max: 10) }
case_run("ft_date")             { date_field_tag("d", "2026-01-02") }
case_run("ft_check")            { check_box_tag("ok", "1", true) }
case_run("ft_check_false")      { check_box_tag("ok", "1", false) }
case_run("ft_radio")            { radio_button_tag("g", "f", true) }
case_run("ft_text_area")        { text_area_tag("body", "hi", rows: 3) }
case_run("ft_search")           { search_field_tag("q", "x") }
case_run("ft_tel")              { telephone_field_tag("p", "123") }
case_run("ft_url_field")        { url_field_tag("u", "https://x.y") }
case_run("ft_color")            { color_field_tag("c", "#ffffff") }
case_run("ft_range")            { range_field_tag("r", 3, min: 0, max: 9) }
case_run("ft_submit")           { submit_tag("Save", class: "b") }
case_run("ft_button")           { button_tag("Cancel") }
case_run("ft_button_value")     { button_tag("Ok", value: "confirm") }
case_run("ft_select")           { select_tag("t", options_for_select([["A", 1], ["B", 2]], 2)) }
case_run("ft_select_prompt")    { select_tag("t", options_for_select([["A", 1]]), prompt: "Pick") }
case_run("ft_select_multiple")  { select_tag("t", options_for_select([["A", 1], ["B", 2]]), multiple: true) }
case_run("ft_options_selected") { options_for_select(%w[a b], "a") }
case_run("ft_form_tag")         { tpl(%q{<%= form_tag "/posts" do %>x<% end %>}) }
case_run("ft_form_tag_method")  { tpl(%q{<%= form_tag "/p", method: :patch do %>x<% end %>}) }

# --- FormTagHelper (FORMS_SUPPORT phase 1) ------------------------
case_run("ft_file_field")        { file_field_tag("avatar", class: "i") }
case_run("ft_file_field_accept") { file_field_tag("avatar", accept: "image/png,image/jpeg") }
case_run("ft_time_field")        { time_field_tag("t", "12:30") }
case_run("ft_time_time_value")   { time_field_tag("t", Time.utc(2026, 1, 2, 12, 30, 45)) }
case_run("ft_datetime_field")    { datetime_field_tag("dt", "2026-01-02T12:30:00Z") }
case_run("ft_datetime_local")    { datetime_local_field_tag("dtl", "2026-01-02T12:30:00") }
case_run("ft_month_field")       { month_field_tag("m", "2026-01") }
case_run("ft_week_field")        { week_field_tag("w", "2026-W23") }
case_run("ft_phone_field")       { phone_field_tag("p", "555") }
case_run("ft_image_submit")      { image_submit_tag("icons/go.png") }
case_run("ft_image_submit_alt")  { image_submit_tag("icons/go.png", alt: "Custom") }
case_run("ft_image_submit_abs")  { image_submit_tag("/go.png") }
case_run("ft_image_submit_url")  { image_submit_tag("https://x.y/go.png") }
case_run("ft_label_opts")        { label_tag("name", "Name", class: "l") }
case_run("ft_button_block")      { tpl(%q{<%= button_tag class: "btn", type: "submit" do %>Go<% end %>}) }
case_run("ft_check_id_nil")      { check_box_tag("user_ids[]", "5", true, id: nil, class: "sw") }
case_run("ft_check_disabled")    { check_box_tag("ok", "1", true, disabled: true) }
case_run("ft_check_opts")        { check_box_tag("ok", "1", true, class: "sw", id: "custom") }
case_run("ft_radio_opts")        { radio_button_tag("g", "f", true, class: "r") }
case_run("ft_radio_disabled")    { radio_button_tag("g", "f", false, disabled: true, id: nil) }
case_run("ft_submit_turbo")      { submit_tag("S", class: "b", data: {turbo_submits_with: "Working"}) }
case_run("ft_select_disabled")   { select_tag("t", options_for_select([["A", 1]]), disabled: true) }
case_run("ft_options_selected_array") { options_for_select([["A", 1], ["B", 2]], [1, 2]) }
case_run("ft_label_block")       { tpl(%q{<%= label_tag "name", class: "l" do %>Text<% end %>}) }

# --- FormHelper / FormBuilder ------------------------------------
POST = PostModel.new(id: 7, title: "Hi", body: "Words <b>here</b>", published: true, visits: 42, due: Time.utc(2026, 1, 2, 12, 30))

# Collections for FormOptionsHelper (phase 2) / select builders (3.4).
Room      = Struct.new(:id, :name)
Continent = Struct.new(:name, :countries)
ROOMS = [Room.new(1, "Alpha"), Room.new(2, "Beta")]
CONTINENTS = [
  Continent.new("Africa", [Room.new(1, "Egypt"), Room.new(4, "Rwanda")]),
  Continent.new("Asia",   [Room.new(3, "China"), Room.new(12, "India")]),
]
PSEL = PostModel.new(id: 8, title: "T", author_id: 2, author_ids: [12])

case_run("fw_url")              { tpl(%q{<%= form_with url: "/x" do |f| %>B<% end %>}) }
case_run("fw_model_new")        { tpl(%q{<%= form_with model: PostModel.new(id: nil, title: "t"), url: "/posts" do |f| %><%= f.text_field :title %><% end %>}) }
case_run("fw_model")            { tpl(%q{<%= form_with model: POST, url: "/posts" do |f| %><%= f.text_field :title %><%= f.text_area :body %><%= f.check_box :published %><%= f.submit "Go" %><% end %>}) }
case_run("fw_label")            { tpl(%q{<%= form_with model: POST, url: "/posts" do |f| %><%= f.label :title %><% end %>}) }
case_run("fw_fields")           { tpl(%q{<%= form_with model: POST, url: "/posts" do |f| %><%= f.hidden_field :id %><% end %>}) }
case_run("fw_field_name")       { tpl(%q{<%= form_with model: POST, url: "/posts" do |f| %><%= f.field_name(:title) %><% end %>}) }

# --- FormHelper / FormBuilder (FORMS_SUPPORT phase 3 + 4a) --------
case_run("fw_file_multipart")   { tpl(%q{<%= form_with scope: "user", url: "/u" do |f| %><%= f.file_field :avatar, class: "input" %><% end %>}) }
case_run("fw_check_values")     { tpl(%q{<%= form_with scope: "user", url: "/u" do |f| %><%= f.check_box :role, {class: "sw"}, "administrator", "member" %><% end %>}) }
case_run("fw_check_values_checked") { tpl(%q{<%= form_with model: POST, url: "/posts" do |f| %><%= f.check_box :published, {class: "sw"}, "true", "false" %><% end %>}) }
case_run("fw_no_block")         { tpl(%q{<%= form_with url: "/u/1", method: :delete %>}) }
case_run("fw_typed_text")       { tpl(%q{<%= form_with model: POST, url: "/posts" do |f| %><%= f.email_field :title %><%= f.search_field :title %><%= f.telephone_field :title %><%= f.url_field :title %><%= f.color_field :title %><% end %>}) }
case_run("fw_typed_num")        { tpl(%q{<%= form_with model: POST, url: "/posts" do |f| %><%= f.number_field :visits %><%= f.range_field :visits, min: 0, max: 9 %><% end %>}) }
case_run("fw_typed_date")       { tpl(%q{<%= form_with model: POST, url: "/posts" do |f| %><%= f.date_field :due %><%= f.time_field :due %><%= f.datetime_field :due %><%= f.datetime_local_field :due %><%= f.month_field :due %><%= f.week_field :due %><% end %>}) }
case_run("ff_radio_opts")       { tpl(%q{<%= form_with model: POST, url: "/posts" do |f| %><%= f.radio_button :title, "Hi", class: "r" %><%= f.radio_button :title, "No" %><% end %>}) }
case_run("ff_button")           { tpl(%q{<%= form_with model: POST, url: "/posts" do |f| %><%= f.button "Go" %><% end %>}) }
case_run("ff_button_block")     { tpl(%q{<%= form_with model: POST, url: "/posts" do |f| %><%= f.button class: "b" do %>Block<% end %><% end %>}) }
case_run("ff_label_block")      { tpl(%q{<%= form_with model: POST, url: "/posts" do |f| %><%= f.label(:title) { "Custom" } %><% end %>}) }
case_run("ff_field_id")         { tpl(%q{<%= form_with model: POST, url: "/posts" do |f| %><%= f.field_id :title %><% end %>}) }
case_run("ff_hidden_value")     { tpl(%q{<%= form_with model: POST, url: "/posts" do |f| %><%= f.hidden_field :title, value: "X" %><% end %>}) }

# --- FormOptionsHelper + select builders (FORMS_SUPPORT phase 2 + 3.4)
case_run("fo_from_collection")     { options_from_collection_for_select(ROOMS, :id, :name, 2) }
case_run("fo_from_collection_none"){ options_from_collection_for_select(ROOMS, :id, :name) }
case_run("fo_from_collection_dis") { options_from_collection_for_select(ROOMS, :id, :name, {selected: 2, disabled: 1}) }
case_run("fo_grouped")             { grouped_options_for_select({"G" => [["A", 1], ["B", 2]], "H" => ["C"]}, 2) }
case_run("fo_grouped_prompt")      { grouped_options_for_select({"G" => [["A", 1]]}, nil, prompt: "Pick") }
case_run("fo_option_groups")       { option_groups_from_collection_for_select(CONTINENTS, :countries, :name, :id, :name, 3) }
case_run("fs_select")              { tpl(%q{<%= form_with model: POST, url: "/posts" do |f| %><%= f.select :title, [["One", "Hi"], ["Two", "No"]] %><% end %>}) }
case_run("fs_select_include_blank"){ tpl(%q{<%= form_with model: POST, url: "/posts" do |f| %><%= f.select :title, [["One", "Hi"]], include_blank: true %><% end %>}) }
case_run("fs_select_prompt")       { tpl(%q{<%= form_with model: POST, url: "/posts" do |f| %><%= f.select :title, [["One", "Hi"]], prompt: "Pick" %><% end %>}) }
case_run("fs_select_html_opts")    { tpl(%q{<%= form_with model: POST, url: "/posts" do |f| %><%= f.select :title, [["One", "Hi"]], {}, class: "s" %><% end %>}) }
case_run("fs_select_multiple")     { tpl(%q{<%= form_with model: POST, url: "/posts" do |f| %><%= f.select :title, [["One", "Hi"], ["Two", "No"]], {}, multiple: true %><% end %>}) }
case_run("fs_collection_select")   { tpl(%q{<%= form_with model: POST, url: "/posts" do |f| %><%= f.collection_select :author_id, ROOMS, :id, :name %><% end %>}) }
case_run("fs_collection_select_sel"){ tpl(%q{<%= form_with model: PSEL, url: "/posts" do |f| %><%= f.collection_select :author_id, ROOMS, :id, :name %><% end %>}) }
case_run("fs_collection_prompt")   { tpl(%q{<%= form_with model: POST, url: "/posts" do |f| %><%= f.collection_select :author_id, ROOMS, :id, :name, prompt: true %><% end %>}) }
case_run("fs_grouped_select")      { tpl(%q{<%= form_with model: PSEL, url: "/posts" do |f| %><%= f.grouped_collection_select :author_id, CONTINENTS, :countries, :name, :id, :name %><% end %>}) }
case_run("fs_collection_checks")   { tpl(%q{<%= form_with model: PSEL, url: "/posts" do |f| %><%= f.collection_check_boxes :author_ids, ROOMS, :id, :name %><% end %>}) }
case_run("fs_collection_radios")   { tpl(%q{<%= form_with model: PSEL, url: "/posts" do |f| %><%= f.collection_radio_buttons :author_id, ROOMS, :id, :name %><% end %>}) }
case_run("fs_weekday")             { tpl(%q{<%= form_with scope: "u", url: "/u" do |f| %><%= f.weekday_select :day %><% end %>}) }

# --- app-config form semantics (load_defaults 6.1+: local forms,
# --- no utf8 enrollment, generated ids) ----------------------------
case_run("fw_local") do
  ActionView::Helpers::FormHelper.form_with_generates_remote_forms = false
  ActionView::Helpers::FormTagHelper.default_enforce_utf8 = false
  ActionView::Helpers::FormHelper.form_with_generates_ids = true
  tpl(%q{<%= form_with url: "/session", class: "flex flex-column gap" do |form| %><%= form.email_field :email_address, required: true, class: "input", autofocus: true, autocomplete: "username", placeholder: "Enter your email address", value: "" %><%= form.password_field :password, required: true, class: "input", autocomplete: "current-password", placeholder: "Enter your password", maxlength: 72 %><%= form.button class: "btn btn--reversed center txt-large", type: "submit", name: "log_in" do %>Go<% end %><% end %>})
ensure
  ActionView::Helpers::FormHelper.form_with_generates_remote_forms = true
  ActionView::Helpers::FormTagHelper.default_enforce_utf8 = true
  ActionView::Helpers::FormHelper.form_with_generates_ids = false
end
case_run("fw_ids_model") do
  ActionView::Helpers::FormHelper.form_with_generates_ids = true
  tpl(%q{<%= form_with model: POST, url: "/posts" do |f| %><%= f.text_field :title %><%= f.label :title %><% end %>})
ensure
  ActionView::Helpers::FormHelper.form_with_generates_ids = false
end
case_run("ff_password")         { tpl(%q{<%= form_with model: POST, url: "/posts" do |f| %><%= f.password_field :title %><% end %>}) }
case_run("ff_text_nil")         { tpl(%q{<%= form_with model: POST, url: "/posts" do |f| %><%= f.text_field :author_id %><% end %>}) }
case_run("ff_textarea_value")  { tpl(%q{<%= form_with model: POST, url: "/posts" do |f| %><%= f.text_area :body, value: "OVERRIDE", rows: 3 %><% end %>}) }

# --- Partials (on-disk fixtures in oracle/fixtures) ---------------
# A second standalone view whose lookup paths point at the fixtures
# dir, so partials resolve from disk exactly like a real app.
PVIEW = OracleView.with_empty_template_cache.new(
  ActionView::LookupContext.new([File.expand_path("fixtures", __dir__)]), {}, nil
)
P1 = PostModel.new(id: 1, title: "One")
P2 = PostModel.new(id: 2, title: "Two")

case_run("prt_locals") do
  PVIEW.render(partial: "post", locals: {post: POST}).strip
end
case_run("prt_collection") do
  PVIEW.render(partial: "post", collection: [P1, P2]).strip
end
case_run("prt_collection_empty") do
  # Rails returns nil for an empty collection; through a template the
  # rendered output is "" — compare at the template level.
  PVIEW.render(inline: %q{<%= render partial: "post", collection: [] %>}, formats: [:html]).strip
end
case_run("prt_collection_as") do
  PVIEW.render(partial: "row", collection: [P1, P2], as: :post).strip
end
case_run("prt_nested") do
  PVIEW.render(partial: "wrap", locals: {p: POST}).strip
end
case_run("prt_spacer") do
  PVIEW.render(partial: "post", collection: [P1, P2], spacer_template: "dash").strip
end

# --- CaptureHelper / content_for (via layout) --------------------
case_run("cap_content_for")     { tpl(%q{<% content_for :sidebar do %>S<% end %>B}) }

# --- fields_for (view-level + builder-level nested forms) ---------
NP1 = PostModel.new(id: 101, title: "First")          # persisted child
NP2 = PostModel.new(id: nil, title: "New one")        # new child
U  = UserModel.new(id: 5, name: "Oleg")
U.posts << NP1
U.posts << NP2
C  = PostModel.new(id: 9, title: "Com")               # non-nested record

case_run("ff_view") do
  tpl(%q{<%= fields_for :post, NP1 do |f| %><%= f.text_field :title %><% end %>})
end
case_run("ff_view_model") do
  tpl(%q{<%= fields_for NP1 do |f| %><%= f.text_field :title %><% end %>})
end
case_run("ff_view_scope_str") do
  tpl(%q{<%= fields_for "user[post]", NP1 do |f| %><%= f.text_field :title %><% end %>})
end
case_run("ff_nested") do
  tpl(%q{<%= form_with model: U, url: "/users" do |f| %><%= f.fields_for :posts do |g| %>[<%= g.text_field :title %>]<% end %><% end %>})
end
case_run("ff_nested_explicit") do
  tpl(%q{<%= form_with model: U, url: "/users" do |f| %><%= f.fields_for :posts, PostModel.new(id: 55, title: "Explicit") do |g| %><%= g.text_field :title %><% end %><% end %>})
end
case_run("ff_child_index") do
  tpl(%q{<%= form_with model: U, url: "/users" do |f| %><%= f.fields_for :posts, U.posts.first, child_index: 777 do |g| %><%= g.text_field :title %><% end %><% end %>})
end
case_run("ff_destroy") do
  tpl(%q{<%= form_with model: U, url: "/users" do |f| %><%= f.fields_for :posts, U.posts.first do |g| %><%= g.check_box :_destroy %><% end %><% end %>})
end
case_run("ff_include_id_false") do
  tpl(%q{<%= form_with model: U, url: "/users" do |f| %><%= f.fields_for :posts, U.posts.first, include_id: false do |g| %><%= g.text_field :title %><% end %><% end %>})
end
case_run("ff_non_nested") do
  tpl(%q{<%= form_with model: U, url: "/users" do |f| %><%= f.fields_for :comment, C do |g| %><%= g.text_field :title %><% end %><% end %>})
end

# --- Fragment cache ------------------------------------------------
# With no controller (VIEW) perform_caching is false: cache/cache_if/
# cache_unless simply yield the block (stable Rails default). A second
# view with a caching controller proves hits/misses: re-rendering a
# different template under the same key must return the cached content.
class OracleCacheController
  def initialize
    @cache_store = ActiveSupport::Cache::MemoryStore.new
  end
  def perform_caching; true; end
  def read_fragment(name, options = nil)
    value = @cache_store.read(key_for(name))
    value && value.html_safe
  end
  def write_fragment(name, value, options = nil)
    @cache_store.write(key_for(name), value, options && options[:expires_in])
    value
  end
  private
  def key_for(name)
    name.is_a?(Array) ? name.join("/") : name.to_s
  end
end
CVIEW = OracleView.with_empty_template_cache.new(
  ActionView::LookupContext.new([]), {}, OracleCacheController.new
)
def ctpl(src)
  CVIEW.render(inline: src, formats: [:html]).strip
end

case_run("cache_off") do
  tpl(%q{A<% cache("cache_off") do %>X<% end %>B})
end
case_run("cache_off_if") do
  tpl(%q{<% cache_if(false, "k") do %>N<% end %>})
end
case_run("cache_off_unless") do
  tpl(%q{<% cache_unless(true, "k") do %>N<% end %>})
end
case_run("cache_on_hit") do
  [
    ctpl(%q{A<% cache("hit1") do %>HELLO<% end %>B}),
    ctpl(%q{A<% cache("hit1") do %>WORLD<% end %>B}),
  ].join("|")
end
case_run("cache_on_cond") do
  src1 = %q{<% cache_if(true, "c1") do %>A<% end %><% cache_if(false, "c2") do %>C<% end %><% cache_unless(false, "c3") do %>E<% end %>}
  src2 = %q{<% cache_if(true, "c1") do %>B<% end %><% cache_if(false, "c2") do %>D<% end %><% cache_unless(false, "c3") do %>F<% end %>}
  [ctpl(src1), ctpl(src1), ctpl(src2)].join("|")
end
