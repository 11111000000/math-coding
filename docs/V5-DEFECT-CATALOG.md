# Каталог обязательных отказов

Каждый сценарий имеет accepting и rejecting fixture. Старая v4 может быть
использована только как отрицательный образец.

1. Проверка без control не даёт `Holds`.
2. Control изменил elsewhere/nothing — `Holds` запрещён.
3. Проверка упала по несвязанной причине — нет установленного утверждения.
4. Хотя бы один путь scope вне цели — отказ.
5. Просроченное ревью видно в map и route.
6. Изменение claim definition инвалидирует evidence.
7. Изменение verifier инвалидирует зависимые evidence.
8. Изменение environment не допускает сравнение evidence.
9. Истёкший waiver возвращает gap, `Refuted` не покрывается.
10. Standing не может быть назначен произвольному факту о коде.
11. Untracked файл входит в repository surface.
12. Dirty working tree совпадает с digest того же содержимого, а не HEAD.
13. Symlink, Unicode, spaces и удалённые пути обрабатываются без потерь.
14. Несуществующий scope не даёт digest.
15. Команда 127 — `not-run`, не fail и не pass.
16. Timeout/signal/setup failure — `infrastructure-error`.
17. Пустой scope — не wildcard freshness.
18. Неизвестное/duplicate nested JSON field отклоняется.
19. Изменение теста вместе с реализацией — отдельный protected transition.
20. Политика не может авторизовать саму себя.
21. Старый trail без обязательных привязок — `legacy_unverified`.
22. ADR не меняется при import/adopt.
23. Изменение ADR даёт `source_changed`, но не переписывает историю.
24. `acceptance.any` не превращается молча в `all` или пропадает.
25. Нет placeholder scope и автоматической активации import.
26. `map`, `next`, `context` не изменяют файловую систему.
27. Control не меняет живое дерево даже при сбое.
28. MCP stdout содержит только JSON-RPC; ошибка домена — `isError=true`.
29. `structuredContent` соответствует `outputSchema`.
30. Установленный `stand` находит установленный `mathc` без MATHC.
31. Portable не ссылается на Nix interpreter/RPATH.
32. `doctor` сообщает об устаревшей/отсутствующей странице без изменения её.
33. Удалённые файлы не появляются в repository surface и isolated snapshot;
    новые файлы входят в индекс копии для Git/Nix-проверок.
34. Установленный `.#stand` содержит `mathc` рядом и проходит внешний smoke.
35. Повреждённый evidence trail и неизвестный `record --outcome` отклоняются
    без исключения или подмены класса результата.
36. Timeout, сигнал и необычный код выхода — `infrastructure-error`, не `not-run`.
