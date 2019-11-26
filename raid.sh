#!/bin/bash

sudo mkdir -p ~root/.ssh
sudo cp ~vagrant/.ssh/auth* ~root/.ssh
sudo yum install -y mdadm smartmontools hdparm gdisk

# 1. занулим суперблоки на всех дисках, собираемых в райд указав разом все диски
sudo mdadm --zero-superblock --force /dev/sd{b..g}
echo "1 - done"

# 2. создадим массив 1-го уровня для дисков f,g
sudo mdadm --create --verbose --run /dev/md0 -l 1 -n 2 /dev/sd{f,g}
echo "2 - done"

# 3. запишем инфу в конфиг файл для автоматического подключения райда при загрузке
sudo mkdir /etc/mdadm/ 
sudo echo "DEVICE partitions" > mdadm.conf 
sudo mdadm --detail --scan --verbose | awk '/ARRAY/ {print}' >> mdadm.conf 
sudo mv mdadm.conf /etc/mdadm/
echo "3 - done"

# 4. создаем GPT на райде
sudo parted -s /dev/md0 mklabel gpt && echo "4 - done"

# 5. создаем партиции на райде
sudo parted -s /dev/md0 mkpart primary ext4 0% 20%
sudo parted -s /dev/md0 mkpart primary ext4 20% 40%
sudo parted -s /dev/md0 mkpart primary ext4 40% 60%
sudo parted -s /dev/md0 mkpart primary ext4 60% 80%
sudo parted -s /dev/md0 mkpart primary ext4 80% 100%
echo "5 - done"

# 6. создаем файловую систему на разделах
for i in $(seq 1 5); do sudo mkfs.ext4 /dev/md0p$i; done
echo "6 - done"

# 7. создадим каталоги для разделов по part1..part5
sudo mkdir -p /raid/part{1,2,3,4,5}
echo "7 - done"

# 8. смонтируем разделы по каталогам part1..part5
sudo mount /dev/md0p1 /raid/part1
sudo mount /dev/md0p2 /raid/part2
sudo mount /dev/md0p3 /raid/part3
sudo mount /dev/md0p4 /raid/part4
sudo mount /dev/md0p5 /raid/part5
sudo echo "8 - done"
