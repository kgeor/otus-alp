# Задание: Обновление ядра и сборка образа системы
## Развертывание "чистого" образа ОС и обновление ядра вручную
*При выполнении данного задания в качестве ОС будет использоваться Rocky Linux 9.1*

Создадим папку под выполнение данного задания

```mkdir -p ~/labs/lab1 && cd ~/labs/lab1```

и создадим в ней Vagrantfile со следующим содержимым:
```
Vagrant.configure(2) do |config|
  #Какой vm box будем использовать
  config.vm.box = "kgeor/rocky9-kernel6"
  config.vm.synced_folder ".", "/vagrant", disabled: true
  config.vm.provider "virtualbox" do |vb|
    # имя виртуальной машины
    vb.name = "rocky9-kernel6"
    # объем оперативной памяти
    vb.memory = 2048
    # количество ядер процессора
    vb.cpus = 2
  end
  #hostname виртуальной машины
  config.vm.hostname = "rocky9-kernel-update""
end
```
После развертывания ВМ проверим текущую версию ядра

```
[vagrant@rocky9-kernel-update ~]$ uname -r
5.14.0-162.18.1.el9_1.x86_64
```

Далее подключим репозиторий, откуда возьмём необходимую версию ядра:

```sudo dnf -y install https://www.elrepo.org/elrepo-release-9.el9.elrepo.noarch.rpm```

Установим последнее ядро из репозитория elrepo-kernel:

```sudo dnf --enablerepo elrepo-kernel install kernel-ml -y```

Конфигурация загрузчика обновилась автоматически, поэтому просто перезагруpbм ВМ

```sudo reboot now```

После перезагрузки снова проверяем версию ядра

```
[vagrant@rocky9-kernel-update ~]$ uname -r
6.2.2-1.el9.elrepo.x86_64
```
## Создание образа с обновленным ядром автоматизированно
*Для создания образа будем использовать Packer, все упомянутые далее файлы конфигурации находятся в данном репозитории.*

В каталоге с нашим Vagrantfile создадим папку packer и перейдем в нее

```mkdir packer && cd packer```

Далее создаем для Packer файл *rocky9.pkr.hcl* в формате HCL, в котором опишем все параметры развертывания и настройки ОС, которым должен следовать Packer.

Теперь необходимо создать директорию http и добавить в нее файл автоматической конфигурации ОС для Kickstart *ks.cfg*
Последним шагом создаем директорию scripts, в которую помещаем указанные в разделеprovisioners файла конфигурации Packer скрипты настройки и обновления системы, установки нового ядра, VBox Guest Additions.

После этого можно запускать процесс создания образа для vagrant командой

```packer build rocky9.pkr.hcl```

Полученный вывод говорит об успешном завершении процесса

```
...
==> Builds finished. The artifacts of successful builds are:
--> virtualbox-iso.virtualbox: 'virtualbox' provider box: Rocky9.1-x86_64-base.box
[kgeor@rocky-ls packer]$
```
После успешного завершения сборки и экспорта образа в указанный формат .box проверим корректность полученного образа

```
[kgeor@rocky-ls lab1]$ vagrant box add rocky.json --force
==> box: Loading metadata for box 'rocky.json'
    box: URL: file:///home/kgeor/labs/lab1/rocky.json
==> box: Adding box 'kgeor/rocky9-kernel6' (v1) for provider: virtualbox
    box: Unpacking necessary files from: file:///home/kgeor/labs/lab1/packer/Rocky9.1-x86_64-base.box
==> box: Successfully added box 'kgeor/rocky9-kernel6' (v1) for 'virtualbox'!
[kgeor@rocky-ls lab1]$ vagrant up
Bringing machine 'default' up with 'virtualbox' provider...
==> default: Importing base box 'kgeor/rocky9-kernel6'...
...
==> default: Machine booted and ready!
==> default: Checking for guest additions in VM...
==> default: Setting hostname...
==> default: Mounting shared folders...
    default: /vagrant => /home/kgeor/labs/lab1
[kgeor@rocky-ls lab1]$ vagrant ssh
Activate the web console with: systemctl enable --now cockpit.socket

[vagrant@rocky9-kernel6 ~]$ uname -r
6.2.2-1.el9.elrepo.x86_64
[vagrant@rocky9-kernel6 ~]$ ls /vagrant/
Vagrantfile  packer  readme.md  rocky.json
```
Осталось залить образ в Vagrant Cloud, а конфигурационные файлы в репозиторий Github.
```
vagrant cloud auth login
vagrant cloud publish --release kgeor/rocky9-kernel6 1.0 virtualbox Rocky9.1-x86_64-base.box
```
**PROFIT!**
