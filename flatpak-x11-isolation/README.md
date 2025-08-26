# Для работы необходимо установить следующие пакеты:
```sh
sudo apt install xserver-xephyr openbox xdotool wmctrl x11-xserver-utils xbindkeys
```

# Есть 2 варианта установки:
## Первый
Перезапись /usr/bin/flatpak
1. Переносите /usr/bin/flatpak в /usr/bin/flatpak.orig
2. Создаете файл flatpak и вставляете туда скрипт из этой папки

Я рекомендую этот скрипт, потому что он автоматически заработает с desktop ярлыками.

## Второй
Создание ~/bin
1. Создать директорию для скриптов: `mkdir -p ~/bin`
2. Вставляете скрипт в: `nano ~/bin/flatpak-xephyr`
3. Делаете исполняемым: `chmod +x ~/bin/flatpak-xephyr`
4. Добавить ~/bin в PATH: `echo 'export PATH="$HOME/bin:$PATH"' >> ~/.bashrc`
5. Создать алиас для автоматического использования: `echo 'alias flatpak="$HOME/bin/flatpak-xephyr"' >> ~/.bashrc`
6. Перезагрузить bashrc: `source ~/.bashrc`

Далее вручную убираете из `/var/lib/flatpak/exports/share/applications` (папка с desktop файлами) `Exec=/usr/bin/flatpak` > `Exec=flatpak`.

Для удобства команда для автоматической замены с `sudo`:
### Показать изменения (dry-run — просто посмотреть, какие файлы затронуты)
```sh
sudo grep -R --line-number --color=always "Exec=.*\/usr\/bin\/flatpak" /var/lib/flatpak/exports/share/applications || true
```
### Сделать замену прямо в `.desktop` файлах (только в строках `Exec=`):
```sh
sudo find -L /var/lib/flatpak/exports/share/applications \
  -name '*.desktop' -exec sed -i -E "/^Exec=/ s|/usr/bin/flatpak|$HOME/bin/flatpak-xephyr|g" {} +
```
### Проверить результат:
```sh
grep -R --line-number '^Exec=.*flatpak*' /var/lib/flatpak/exports/share/applications || true
```

## Конфиги
Вы можете добавить какое-либо приложение в "черный список" xephyr, и он будет запускаться на родном x11.
```
$ flatpak xephyr-help
Flatpak Xephyr Wrapper v1.1

Этот скрипт заменяет стандартный flatpak и автоматически запускает
приложения в изолированном X-сервере (Xephyr).

ИСПОЛЬЗОВАНИЕ:
    flatpak [команда] [опции]

СПЕЦИАЛЬНЫЕ КОМАНДЫ:
    flatpak xephyr-exclude APP_ID    - Добавить приложение в исключения
    flatpak xephyr-include APP_ID    - Удалить приложение из исключений
    flatpak xephyr-list              - Показать список исключений
    flatpak xephyr-status            - Показать статус и конфигурацию
    flatpak xephyr-help              - Показать эту справку
    flatpak xephyr-test APP_ID       - Тестовый запуск с отладкой

ПЕРЕМЕННЫЕ ОКРУЖЕНИЯ:
    FLATPAK_XEPHYR=false         - Отключить Xephyr для текущего запуска
    FLATPAK_XEPHYR_RES=WxH       - Установить разрешение (по умолчанию: 1280x720)
    DEBUG=1                      - Включить отладочные сообщения

ПРИМЕРЫ:
    flatpak run org.telegram.desktop
    flatpak run --branch=stable --arch=x86_64 org.gimp.GIMP
    flatpak run --command=missioncenter io.missioncenter.MissionCenter
    FLATPAK_XEPHYR=false flatpak run org.gimp.GIMP

ФАЙЛЫ КОНФИГУРАЦИИ:
    ~/.config/flatpak-xephyr/exclude.conf    - Список исключений
    ~/.config/flatpak-xephyr/xephyr.log      - Лог файл
```

## Советы
1. Открывайте окна внутри xephyr в полноэкранном режиме, так будет меньше проблем с "черными экранами". Скрипт все равно автоматически пытается изменить размеры окон, чтобы таких проблем не было. Но с некоторыми приложениями все равно могут быть проблемы.
