# Изоляция .deb приложений
В данной папке содержатся скрипты для изоляции заготовленных файлов с настройкой нужных прав доступа.

На их примере вы можете изолировать любое .deb приложение, но учитывайте, что придется подкорректировать скрипт запуска и аргументы bwrap.

## Проблемы
1. Отсутствует общий буфер обмена
2. Отсутствует переключение раскладки клавиатуры

## Установка пакетов
```
sudo apt install bubblewrap xserver-xephyr x11-xserver-utils 
```

## Установка Yandex Music
1. Создайте папку `mkdir -p ~/.local/bwrap-apps`
2. Скачайте .deb файл Яндекс Музыки
3. Распакуйте .deb файл в bwrap-apps: `dpkg-deb -x приложение.deb ~/.local/bwrap-apps/YandexMusic/`
4. Скачайте файл `YandexMusic.sh` в папку `~/.local/bwrap-apps` (`nano ~/.local/bwrap-apps/YandexMusic.sh`)
5. Выдайте права на исполнение для скрипта: `chmod +xxx ~/.local/bwrap-apps/YandexMusic.sh`
6. Создайте .desktop файл в `/usr/share/applications` (с sudo, на cutefish только тут, даже при использовании патча на фикс) или `~/.local/applications`
7. Вставьте текст из `yandexmusic.desktop` файла, заменив `/home/user` на папку своего пользователя (`echo "$HOME"`). На cutefish эта енва сама не ставится.
