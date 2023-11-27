# LDAP
Задание:
1) Установить FreeIPA;
2) Написать Ansible playbook для конфигурации клиента;
3) Настроить аутентификацию по SSH-ключам*
4) Firewall должен быть включен на сервере и на клиенте*
## Выполнение
После развертывания мы получаем уже готовый FreeIPA сервер с двумя добавленными клиентами, для проверки работоспособности сначала зайдем на `ipa.otus.lan`, авторизуемся как администратор домена и добавим нового пользователя otus-user
```
[root@ipa ~]# kinit admin
Password for admin@OTUS.LAN: otus2023
[root@ipa ~]# ipa user-add otus-user --first=Otus --last=User --password
Password:
Enter Password again to verify:
----------------------
Added user "otus-user"
...
```
Попробуем авторизоваться на одном из клиентов
```
[root@client2 ~]# kinit otus-user
Password for otus-user@OTUS.LAN:
Password expired.  You must change it now.
Enter new password:
Enter it again:
[root@client2 ~]# klist
Ticket cache: KCM:0
Default principal: otus-user@OTUS.LAN

Valid starting       Expires              Service principal
08/29/2023 17:09:49  08/30/2023 17:09:13  krbtgt/OTUS.LAN@OTUS.LAN
```
Все работает корректно.

**PROFIT!!!!!**
