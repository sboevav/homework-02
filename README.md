# Инструкции

* [Как начать Git](git_quick_start.md)
* [Как начать Vagrant](vagrant_quick_start.md)

## otus-linux

Используйте этот [Vagrantfile](Vagrantfile) - для тестового стенда.

# Решение

1.  исправим Vagrantfile
добавлены диски 
                :sata15 => {
                        :dfile => './sata15.vdi',
                        :size => 100,
                        :port => 5
                },
                :sata16 => {
                        :dfile => './sata16.vdi',
                        :size => 100, # Megabytes
                        :port => 6
                }
примечание - первоначально система была поднята с существующими 4-мя дисками, в качестве эксперимента виртуалка была полностью удалена со всеми фалйми virtualbox и созданными фалйами vagrant (диски: sata1.vdi и.т.д., и папка .vagrant) После этого виртуалка больше не поднималась - ругалась на наличие файлов имевшихся ранее дисков. Где еще сохранялась информация по дискам кроме  virtualbox и папки с Vagrantfile я не нашел, может где в реестре? . Переименовал все диски (добавил десятку к номерам) sata1 -> sata11 и.тд., после этого все поехало нормально.

2. поднимем виртуалку 
vagrant up

3. проверим наличие дисков
$ sudo fdisk -l
убеждаемся

4. занулим суперблоки на всех дисках, собираемых в райд указав разом все диски
$ sudo mdadm --zero-superblock --force /dev/sd{b..g}
если видим такой ответ - то все нормально, диски не были в райде 
mdadm: Unrecognised md component device - /dev/sdb
mdadm: Unrecognised md component device - /dev/sdc
mdadm: Unrecognised md component device - /dev/sdd
mdadm: Unrecognised md component device - /dev/sde
mdadm: Unrecognised md component device - /dev/sdf
mdadm: Unrecognised md component device - /dev/sdg

5. создадим массив 1-го уровня для дисков f,g
$ sudo mdadm --create --verbose /dev/md0 -l 1 -n 2 /dev/sd{f,g}
-l 1 - райд уровня 1
-n 2 - два диска /dev/sd{f,g}
--verbose - что это такое нифига не нашел

6. проверим статус
$ cat /proc/mdstat
получили
Personalities : [raid1]
md0 : active raid1 sdg[1] sdf[0]
      101376 blocks super 1.2 [2/2] [UU]
unused devices: <none>

7. запишем инфу в конфиг файл для автоматического подключения райда при загрузке
$ sudo echo "DEVICE partitions" > /etc/mdadm/mdadm.conf
$ sudo mdadm --detail --scan --verbose | awk '/ARRAY/ {print}' >> /etc/mdadm/mdadm.conf
примечание - здесь тоже слуичлся непонятный мне косяк.
Изначально эти команды выполнить не удалось - отказано в доступе.
Создал каталог и файл вручную, повторил попытку - отказано в доступе.
при этом файл в принципе редактируется в vim.
Помогла команда sudo su, после чего эти команды нормально отработали.
Не понимаю почему $ sudo echo "DEVICE partitions" > /etc/mdadm/mdadm.conf не проходит.

8. убедимся в нормальном состоянии райда перед поломкой
$ sudo  mdadm -D /dev/md0
/dev/md0:
           Version : 1.2
     Creation Time : Sat Nov  9 17:03:20 2019
        Raid Level : raid1
        Array Size : 101376 (99.00 MiB 103.81 MB)
     Used Dev Size : 101376 (99.00 MiB 103.81 MB)
      Raid Devices : 2
     Total Devices : 2
       Persistence : Superblock is persistent

       Update Time : Sat Nov  9 17:03:23 2019
             State : clean
    Active Devices : 2
   Working Devices : 2
    Failed Devices : 0
     Spare Devices : 0

Consistency Policy : resync

              Name : otuslinux:0  (local to host otuslinux)
              UUID : 6e43466d:3f791fcc:c01773c2:bbbb9329
            Events : 17

    Number   Major   Minor   RaidDevice State
       0       8       80        0      active sync   /dev/sdf
       1       8       96        1      active sync   /dev/sdg

9. сломаем диск sdg
$ sudo mdadm /dev/md0 --fail /dev/sdg

10. посмотрим статус райда
$ cat /proc/mdstat
Personalities : [raid1]
md0 : active raid1 sdg[1](F) sdf[0]
      101376 blocks super 1.2 [2/1] [U_]

11. удалим сломанный диск
$ sudo mdadm /dev/md0 --remove /dev/sdg
mdadm: hot removed /dev/sdg from /dev/md0

12. теперь добавим новый диск в райд после замены "сломанного"
$ sudo mdadm /dev/md0 --add /dev/sdg
mdadm: added /dev/sdg

13. посмотрим статус райда
$ cat /proc/mdstat
Personalities : [raid1]
md0 : active raid1 sdg[2] sdf[0]
      101376 blocks super 1.2 [2/2] [UU]

14. создаем GPT на райде
$ sudo parted -s /dev/md0 mklabel gpt

15. создаем партиции на райде
$ sudo parted /dev/md0 mkpart primary ext4 0% 20%
$ sudo parted /dev/md0 mkpart primary ext4 20% 40%
$ sudo parted /dev/md0 mkpart primary ext4 40% 60%
$ sudo parted /dev/md0 mkpart primary ext4 60% 80%
$ sudo parted /dev/md0 mkpart primary ext4 80% 100%
Information: You may need to update /etc/fstab.

16. создаем файловую систему на разделах
$ for i in $(seq 1 5); do sudo mkfs.ext4 /dev/md0p$i; done
... тут куча вывода по каждому разделу и в конце
Allocating group tables: done
Writing inode tables: done
Creating journal (1024 blocks): done
Writing superblocks and filesystem accounting information: done

18. создадим каталоги для разделов по part1..part5
$ sudo mkdir -p /raid/part{1,2,3,4,5}

17. смонтируем разделы по каталогам part1..part5
$ sudo mount /dev/md0p1 /raid/part1
$ sudo mount /dev/md0p2 /raid/part2
$ sudo mount /dev/md0p3 /raid/part3
$ sudo mount /dev/md0p4 /raid/part4
$ sudo mount /dev/md0p5 /raid/part5

