# action_view.cr — порт ActionView (хэлперы, ERB, форм-билдер)

> ⚠️ EXPERIMENTAL FRAMEWORK, DO NOT USE IN PRODUCTION YET.

Неймспейс: `ActionView` — 1:1. Шаблоны: **ERB-синтаксис** (совместимы с
Rails): компилятор и rendering-pipeline вынесены в шард erb_cr
(`ERB::Rendering`, `ERB::SafeString`; см. PLAN_MIGRATION_ERB.md) —
через macro `run()`, как stdlib ECR, генерирует методы-рендеры на
этапе сборки; `<%= %>` автоэкранирует, SafeString — маркер safe-HTML.

## Статус (fields_for + fragment cache добавлено 2026-10-05; Vite P0 2026-10-05, база Iteration 3; Vite P1 dev-теги 2026-10-05)

Оракул: `oracle/cases.rb` → `oracle/expected.yml` (сняты с actionview
8.1.4), спек `spec/oracle_spec.cr`; плюс Vite-слой: оракул
`oracle/vite_cases.rb` → `oracle/vite_expected.yml` (15 кейсов с
настоящих vite_rails 3.0.19 / vite_ruby 3.9.2 — версий из
Gemfile.lock qp2/website) и `oracle/vite_dev_cases.rb` →
`oracle/vite_dev_expected.yml` (13 кейсов dev-режима), зеркало —
`spec/vite_spec.cr`. Сюита — **215 examples, 0 failures** (151 + 29
ft-кейсов фазы 1 + 13 fw_/ff_-кейсов фазы 3/4a + 18 fo_/fs_-кейсов
фаз 2/3.4 + 4 конфиг-кейса fw_local/fw_ids_model/ff_password/
ff_text_nil, FORMS_SUPPORT 2026-10-20).

Формы, FORMS_SUPPORT (2026-10-20, v0.1.3 + v0.1.4):
- фаза 1 (v0.1.3): file/time/datetime/datetime_local/month/week/phone
  `*_tag` + `image_submit_tag`, `button_tag`/`label_tag` с блоком,
  merge-порядок атрибутов `check_box_tag`/`radio_button_tag`
  (`id: nil`, opts до `checked`), дашеризация вложенных data/aria-ключей
- фаза 3 (v0.1.4): `form_with` capture-first (блок рендерится до
  открывающего тега) + multipart от `file_field` (enctype — первый
  атрибут); `form_with` без блока (без `</form>`); `method:` опция;
  типизированные поля билдера (email/search/tel/url/number/range/
  date/time/datetime/datetime_local/month/week/color — датовые и color
  ставят value до type, Time форматируется ISO: %F, %H:%M:%S.%L, %FT%T,
  %Y-%m, %G-W%V); `check_box` с checked/unchecked values (named-args
  отклонение от позиционного хэша Rails) и `hidden:`; `file_field`;
  порядок hidden_field (явный value: на второй позиции); `button`/
  `label` с блоком; публичный `field_id`; id полей — последним
  атрибутом
- фаза 2 + 3.4 (v0.1.5): FormOptionsHelper (options_for_select c
  disabled, options_from_collection_for_select,
  option_groups_from_collection_for_select, grouped_options_for_select
  c prompt) — коллекции через интерфейсы FormOption/GroupOption вместо
  symbol-методов Rails (отклонение); select-билдеры: select /
  collection_select / grouped_collection_select / weekday_select
  (include_blank → <option value="" label=" ">, prompt только при
  пустом значении, multiple → name[] + скрытый companion впереди),
  collection_check_boxes / collection_radio_buttons (скрытый
  companion, форс-ids, label for); checked-значения чекбоксов —
  именованным аргументом checked: (FormValue без массивов —
  отклонение); time_zone_select не портирован (нет TimeZone в
  active_support_cr)
- конфиг семантики форм (v0.1.6, для фазы 5 — load_defaults-8.x
  поведение): `form_with_generates_remote_forms` / `form_with_
  generates_ids` (FormHelper) и `default_enforce_utf8`
  (FormTagHelper) — class_property с дефолтами гема (true/false/true,
  оракул остаётся на дефолтах); при выключении — локальные формы без
  data-remote, без utf8-enrollment, ids полей; порядок атрибутов
  form_with: user-opts, enctype, action, accept-charset, method;
  label получает for при генерации ids; nil-value опускается,
  password без value, size из maxlength

fields_for + fragment cache (2026-10-05):
- `fields_for` (view-level) и `FormBuilder#fields_for` — вложенные
  формы байт-в-байт с 8.1.4 (оракул `ff_*`, 9 кейсов): nested-имена
  `user[posts_attributes][0][title]` c последовательным индексом,
  генерация `id` во вложенных билдерах (Rails fields_for сбрасывает
  skip_default_ids), авто `hidden_field :id` ПОСЛЕ блока для
  persisted-детей (emit_hidden_id), опции `child_index:` /
  `include_id:`; ассоциация через опциональный
  `FormModel#form_nested_children(assoc)`
- fragment cache: `cache`/`cache_if`/`cache_unless`/`fragment_cache_key`
  (оракул `cache_*`, 5 кейсов) — явные строковые ключи без digest,
  конфиг `ActionView.perform_caching`/`.cache_store` (дефолт
  NullStore/off — блок просто рендерится, как Rails без кэширующего
  контроллера)

Vite P0 (2026-10-05): `ViteRuby::Manifest` + `ViteHelper` —
интеграция фронтенд-сборки Vite по модели vite_rails:
- манифест `public/vite/.vite/manifest.json` (формат vite 5/6:
  hashed files, imports, css); конфиг — class-свойства
  (`ViteRuby::Manifest.path`/`entrypoints_dir`/`public_output_dir`)
  + env `CRAILS_VITE_MANIFEST`
- хелперы `vite_asset_path`, `vite_javascript_tag` (script ESM +
  modulepreload импортов + stylesheet css-чанков), `vite_stylesheet_tag`,
  `vite_image_tag`, `vite_client_tag`/`vite_react_refresh_tag`
  (nil — dev-server в P1); байты вывода — байт-в-байт с оракулом
- раздача сборки — `CRails::Middleware::Static` в railties (см. там);
  `/vite/assets/*` получает `Cache-Control: immutable` по умолчанию

Vite P1 dev-режим (2026-10-05): оракул `oracle/vite_dev_cases.rb` →
`oracle/vite_dev_expected.yml` (13 кейсов с настоящих гемов против
TCP-заглушки dev-сервера — `dev_server_running?` гема это реальная
проба), зеркало — dev-блок `spec/vite_spec.cr`:
- `ViteRuby.dev_server_running?`: TCP-проба `dev_server_host:port`
  (env `CRAILS_VITE_HOST`/`CRAILS_VITE_PORT`, дефолт 127.0.0.1:5173),
  кэш 1 с, `run_proxy?` только development (mode из env; тесты —
  `ViteRuby.dev_server_running=`)
- в dev lookup/resolves без манифеста: `/vite/<имя>` (entrypoints
  с того же origin), без modulepreload/stylesheet — как
  `find_manifest_entry` гема
- `vite_client_tag` → `<script src="/vite/@vite/client" crossorigin=
  "anonymous" type="module"></script>`, `vite_react_refresh_tag` →
  javascript_tag с CDATA-обёрткой (байты из оракула); HTTP/ws-прокси —
  `CRails::Middleware::ViteDevProxy` в railties
- оставшиеся отклонения: `config/vite.json` не парсится; `type:` —
  String ("javascript"/"stylesheet") вместо Symbol; кастомные options
  в теги не пробрасываются; skip_proxy/auto_build гема не поддержаны

Сделано (Iteration 3):
- output-safety (SafeString, raw/safe_join/escape_once), tag/content,
  text/number, url (link_to/button_to/mail_to), assets, form_tag-хелперы,
  FormBuilder (`form_with` + поля, интерфейс `ActionView::FormModel`:
  `form_scope`/`form_attributes`/`form_persisted?`)
- fields_for (вложенные формы) и fragment cache — см. статус выше
- rendering: буфер `@__av_buf`, `capture`, `content_for`/`provide`,
  макросы `compile_template`/`compile_layout`/`compile_partials`
- partials + collection-render: `render partial:, locals:, collection:,
  as_local:, spacer_template:`; локали — реальные типизированные
  аргументы скомпилированного метода; `<name>_counter` 0-based
  (поведение Rails 7.1+, подтверждено оракулом)
- newline-семантика Rails 8.1 `load_defaults`: у action-шаблонов chomp
  одного завершающего `\n`, партиалы/layout — байт-в-байт (оракул)

Отклонения (задокументированы):
- locals-хеш — Crystal-литерал: `locals: {"post" => post}`, не рубишный
  `{post: post}` (Ruby-литерал в Crystal — NamedTuple)
- типы локалей партиала декларируются приложением в `compile_partials`
  (compile-time фреймворк; Crystal не позволяет `Object` в generic)
- `fields_for`, sanitize (lexbor), fragment cache, полиморфные url — P2
  → fields_for и fragment cache сделаны (2026-10-05); остались
  sanitize (lexbor) и полиморфные url

## Цель

Вьюхи, пишущиеся как в Rails: те же хелперы, тот же FormBuilder,
layouts/partials/content_for.

## API 1:1

### Рендеринг (P0)
- `app/views/<controller>/<action>.html.erb`; layouts (`layouts/application.html.erb`,
  `yield`, `content_for :sidebar / content_for? / provide`), вложенные
  layouts
- `render partial: "shared/post", locals: {post: @post}`,
  collection-рендер (`render @posts` → `_post.erb`,
  `post_counter`, `post_iteration.size/first?/last?`), spacer_template
- Инстанс-переменные контроллера видны во вьюхе (как в Rails)

### Форм-хелперы (P1)
- `form_with model: @post do |f| ... end` (+ `url:`, `scope:`), `fields_for`
- FormBuilder: `f.label, f.text_field, f.password_field, f.hidden_field,
  f.text_area, f.check_box, f.radio_button, f.file_field, f.select,
  f.collection_select, f.grouped_collection_select, f.submit, f.button,
  f.check_box, f.email_field, f.number_field, f.date_field, ...`,
  `f.field_id/field_name`, индексный нейминг для nested attributes
  (`post[comments_attributes][0][_destroy]`)
- Tag-варианты: `form_tag do end`, `text_field_tag, label_tag,
  select_tag, submit_tag, button_tag, hidden_field_tag, ...`

### Контент и теги (P0)
`content_tag(:div, options) { }`, `tag("br")`, `tag.br` (точечная форма —
фикс-список ~110 HTML-элементов, макрос-генерация), `raw`, `safe_join`,
`escape_once`, `capture`, `concat`; output-safety (SafeBuffer-аналог:
`html_safe`-маркер типа).

### URL/навигация (P0)
`link_to "text", path (options|block)`, `link_to_if/unless`,
`button_to`, `current_page?`, `mail_to, phone_to, sms_to`,
`url_for(model)` (полиморфизм — P2).

### Текст и числа (P0)
`pluralize, truncate, excerpt, highlight, word_wrap, simple_format,
cycle/current_cycle/reset_cycle`; `number_to_currency, number_with_delimiter,
number_with_precision, number_to_human_size, number_to_human,
number_to_percentage, number_to_phone`; `debug`,
`distance_of_time_in_words, time_ago_in_words`; `t/l` (I18n).

### Assets (P1)
`stylesheet_link_tag, javascript_include_tag, javascript_tag, image_tag,
video_tag, audio_tag, favicon_link_tag, csrf_meta_tags, csp_meta_tag`.
Sprockets/Propshaft не портируем: fingerprint-манифест
`public/assets/manifest.json` + `compute_asset_path`.

### Sanitize (P2)
`sanitize, strip_tags, strip_links` — нужен HTML-парсер (lexbor).

### Fragment cache (P2 → сделано 2026-10-05, частично)
`cache(name) { }` / `cache_if` / `cache_unless` / `fragment_cache_key`
(`src/helpers/cache_helper.cr`) — явные строковые ключи; стор
`ActionView.cache_store` (AS::Cache), вкл. `ActionView.perform_caching`.
Осталось (P2): Russian-doll ключи из MD5-дайджеста исходника шаблона
(dependency-tracker по `render`-вызовам), array/object-ключи.

## Реализация

- ERB-компиляция в методы-рендеры при сборке (`run()`-процессор);
  view-контекст = класс с миксинами модулей хелперов.
- FormBuilder — статический набор методов (в Rails они тоже генерятся
  один раз CodeGenerator'ом).
- CSRF-токен в формах — как в Rails (authenticity_token).

## Фазы

- P0: ERB + layouts/partials, content_for, тег/контент/текст/числа/URL-хелперы.
- P1: form_with/FormBuilder полный, tag-хелперы, assets, csrf.
- P2: sanitize (lexbor), fragment cache (digest/Russian-doll — база
  сделана), полиморфные url, collection counter/iteration хвосты.

## Готово, когда

форма из Rails-туториала (`form_with model: @post` + `f.text_field :title`
+ `f.submit`) рендерится байт-в-байт тем же HTML (id/name-конвенции
`post[title]`, authenticity token).

## Зависимости

active_support.cr, action_pack.cr (routes/params), lexbor (P2).
