# Миграция: вынос ERB-слоя в отдельный шард `erb_cr` (репо erb.cr)

Цель: ERB-компилятор, rendering-pipeline и output-safety живут в
отдельном шарде `erb_cr` (git@github.com:OrelSokolov/erb.cr.git),
`action_view_cr` зависит от него. Граница — как в Rails: гем
`erubi`/`erb` отдельно, ActionView отдельно.

## Что переезжает в erb.cr (3 файла, ~330 строк)

| Файл | Становится | Содержимое |
|---|---|---|
| `src/template_processor.cr` | `src/template_processor.cr` | compile-time процессор (через `run()`), ноль зависимостей |
| `src/rendering.cr` | `src/rendering.cr` | `ERB::Rendering` — буфер, `capture`, `content_for`/`provide`, макросы `compile_template`/`compile_layout`/`compile_partials` |
| `src/output_safety.cr` | `src/output_safety.cr` | `ERB::SafeString`, `String#html_safe`/`#html_safe?` |

Что остаётся в action_view.cr: все хелперы, FormBuilder, layouts,
кэш, Vite. `raw`/`escape_once`/`safe_join` остаются хелперами
(в Rails `raw` — тоже ActionView::TagHelper, не ERB).

## Переименования (контракт erb.cr)

- неймспейс: `module ActionView` → `module ERB`; entry `src/erb_cr.cr`
- `ActionView::SafeString` → `ERB::SafeString`
- `__av_out`/`__av_esc`/`@__av_buf`/`@__av_content`/`__av_partial_*`/
  `__av_render_partial`/`__av_render_with_content` → префикс `__erb_`
  (внутри переезжающих файлов; генерируемый процессором код — тоже)
- `AVPartialLocal` → `ERBPartialLocal`

**Не меняется** (проверено grep'ом):
- `action_pack.cr`: имена `__av_tpl_*`/`__av_ts_tpl`/`__av_layout` —
  его собственные def-имена, генерируются его кодегеном и в контракт
  rendering не входят; `::ActionView::SafeString` в сигнатурах
  остаётся валиден через алиас
- мёртвый аргумент `"strip"` в `run(...)` (template_processor читает
  только ARGV[0]) — удаляем передачу, поведение байт-в-байт то же

## Адаптация action_view.cr

1. Удалить `src/template_processor.cr`, `src/rendering.cr`,
   `src/output_safety.cr`.
2. `src/action_view_cr.cr`: `require "erb_cr"`; в `module ActionView`
   добавить `alias SafeString = ERB::SafeString`; в `Helpers` —
   `include ERB::Rendering` вместо `ActionView::Rendering`.
   (Все хелперы ссылаются на `SafeString`/`ActionView::SafeString` —
   алиас делает тип идентичным, правки хелперов не нужны.)
3. `shard.yml`: зависимость `erb_cr: github: OrelSokolov/erb.cr,
   version: ~> 0.1.0`.
4. `shard.override.yml` (не коммитится): `erb_cr: path: ../erb.cr`.
5. `shards install` — в `lib/` появится симлинк на сиблинг-чекаут.

## Адаптация railties.cr

- `shard.override.yml`: добавить `erb_cr: path: ../erb.cr`.
- `shards install` (lib-симлинки создаёт shards из path-зависимостей).

## Спеки erb.cr

Синтетические кейсы компиляции (синтаксис + семантика Rails):
`<%= %>` экранирование, `raw`/SafeString без экранирования, `<% %>`
управляющий код, `<%# %>` комментарии, Erubi-trim, блочные хелперы
`<%= ... do %>`, `capture`, `content_for`/`provide`/`yield`,
partial с locals, collection + `_counter` + spacer_template.
Фикстуры в `spec/fixtures/`.

Оракул `oracle/cases.rb` → `expected.yml` (снят с actionview 8.1.4)
и полный оракул-спек (151 examples) остаются в action_view.cr — они
проверяют интегрированный результат, что и есть критерий
нерегрессии миграции.

## Порядок работ

1. Создать `../erb.cr`: `shard.yml` (name: erb_cr, 0.1.0,
   crystal >= 1.21.0, зависимостей нет), `src/{erb_cr.cr,
   template_processor.cr, rendering.cr, output_safety.cr}`,
   `spec/rendering_spec.cr` + фикстуры, `README.md`, `.gitignore`.
2. Прогнать `crystal spec` в erb.cr — зелёный.
3. Адаптировать action_view.cr (п. выше), `crystal spec` —
   151 examples, 0 failures.
4. railties.cr: override + `shards install`, `crystal spec`.
5. Сборка демо-приложения (проверка цепочки
   action_pack → compile_template → erb.cr).
6. Git: init в erb.cr, commit, remote
   git@github.com:OrelSokolov/erb.cr.git, push; тег v0.1.0 —
   нужен, чтобы `~> 0.1.0` в зависимостях резолвился с github.

## Готово, когда

- erb.cr запушен, `crystal spec` в нём зелёный;
- action_view.cr: оракул 151/151 без правок кейсов и expected.yml;
- railties.cr spec зелёный, демо собирается;
- вывод отрендеренных шаблонов байт-в-байт тот же, что до миграции.
