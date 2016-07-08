# Advanced Experience System
Плагины к AMX Mod X. Система опыта и уровней для сервера Counter-Strike и др.

## Установка
* Скомпилируйте плагины.
	* Для компиляции требуется инклюд [colorchat.inc](http://aghl.ru/webcompiler/include/colorchat.inc) от aghl.
* Укажите как вести учет игроков через квар **aes_track_mode**.
	* при работе через статистику csx (значение **-1**) указывать настройки базы данных не нужно.
* Включите необходимый модуль для работы с БД в файле **addons/amxmodx/configs/modules.ini**.
	* **mysql** - для работы с БД MySQL.
	* **sqlite** - для работы с локальной базой данных SQLite (запись в файл на сервере).
* Укажите данные для подключения к БД в файле **addons/amxmodx/configs/aes/aes.cfg**.
	* для SQLite нужно указать **aes_sql_driver  "sqlite"**
* Настройте систему под себя.
	* настройки **addons/amxmodx/configs/aes/aes.cfg**
	* бонусы **addons/amxmodx/configs/aes/bonus.ini**
	* названия уровней **addons/amxmodx/data/lang/aes.txt**
* Расскомментируйте нужные плагины в **addons/amxmodx/configs/plugins-aes.ini**.
	* **aes_main.amxx** - основной плагин
	* **aes_exp_cstrike.amxx** - начисление опыта и бонусов за убийства и пр. для Counter-Strike.
	* **aes_informer.amxx** - HUD информер и сообщения в чат.
	* **aes_exp_editor.amxx** - меню для администратора.
	* **aes_bonus_system.amxx** - меню бонусов (/anew) и плюшки на спавне.
	* **aes_bonus_cstrike.amxx** - бонусы для Counter-Strike.

## Обновление с версии 0.4
* Обновите конфигурацию в папке **addons/amxmodx/configs/aes**.
* Обновите словари в папке **addons/amxmodx/data/lang**.
* Обновите плагины. 
* Если вы использоваили сохранение в файл (**aes_db_type "1"**):
	* Вкючите модуль **sqlite** в файле **addons/amxmodx/configs/modules.ini**.
	* Укажите квар **aes_sql_driver "sqlite"**.
	* Для импорта записей с файла **addons/amxmodx/data/aes/stats.ini** выполните команду **aes_import** в консоли сервера (*сервера, через ркон, а не в вашей контре*).
* Если вы использвали запись в БД (**aes_db_type "2"**):
	* Квар **aes_sql_password** теперь **aes_sql_pass**.
	* Для обновления таблицы выполните импорт файла **aes_stats_to_05_steamid.sql** в БД если вы вели учет игроков по SteamID.
	* Для обновления таблицы выполните импорт файла **aes_stats_to_05_name.sql** в БД если вы вели учет игроков по нику.
	* Для обновления таблицы выполните импорт файла **aes_stats_to_05_ip.sql** в БД если вы вели учет игроков по IP.
	* Если вы меняли название таблицы (квар **aes_sql_table**) то отредактируйте выше перечисленные .sql файлы в соответствии.
* Если вы использовали расчет опыта на основе статистики csx (**aes_db_type "0"**)
	* Укажите квар **aes_track_mode "-1"**.
* Квар **aes_bonus_firstround** теперь указывается в настройках бонусов через переменную **round**.
* Квар **aes_bonus_time** теперь указывается в настройках бонусов через переменную **time**.
