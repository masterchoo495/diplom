#  Дипломная работа по профессии «Системный администратор»

Содержание
---------

## Задача
Ключевая задача — разработать отказоустойчивую инфраструктуру для сайта, включающую мониторинг, сбор логов и резервное копирование основных данных. Инфраструктура должна размещаться в [Yandex Cloud](https://cloud.yandex.com/) и отвечать минимальным стандартам безопасности: запрещается выкладывать токен от облака в git. Используйте [инструкцию](https://cloud.yandex.ru/docs/tutorials/infrastructure-management/terraform-quickstart#get-credentials).

**Перед началом работы над дипломным заданием изучите [Инструкция по экономии облачных ресурсов](https://github.com/netology-code/devops-materials/blob/master/cloudwork.MD).**

## Инфраструктура
Для развёртки инфраструктуры используйте Terraform и Ansible.  

Не используйте для ansible inventory ip-адреса! Вместо этого используйте fqdn имена виртуальных машин в зоне ".ru-central1.internal". Пример: example.ru-central1.internal  - для этого достаточно при создании ВМ указать name=example, hostname=examle !! 

Важно: используйте по-возможности **минимальные конфигурации ВМ**:2 ядра 20% Intel ice lake, 2-4Гб памяти, 10hdd, прерываемая. 

**Так как прерываемая ВМ проработает не больше 24ч, перед сдачей работы на проверку дипломному руководителю сделайте ваши ВМ постоянно работающими.**

Ознакомьтесь со всеми пунктами из этой секции, не беритесь сразу выполнять задание, не дочитав до конца. Пункты взаимосвязаны и могут влиять друг на друга.

### Сайт
Создайте две ВМ в разных зонах, установите на них сервер nginx, если его там нет. ОС и содержимое ВМ должно быть идентичным, это будут наши веб-сервера.

Используйте набор статичных файлов для сайта. Можно переиспользовать сайт из домашнего задания.

Виртуальные машины не должны обладать внешним Ip-адресом, те находится во внутренней сети. Доступ к ВМ по ssh через бастион-сервер. Доступ к web-порту ВМ через балансировщик yandex cloud.

Настройка балансировщика:

1. Создайте [Target Group](https://cloud.yandex.com/docs/application-load-balancer/concepts/target-group), включите в неё две созданных ВМ.

2. Создайте [Backend Group](https://cloud.yandex.com/docs/application-load-balancer/concepts/backend-group), настройте backends на target group, ранее созданную. Настройте healthcheck на корень (/) и порт 80, протокол HTTP.

3. Создайте [HTTP router](https://cloud.yandex.com/docs/application-load-balancer/concepts/http-router). Путь укажите — /, backend group — созданную ранее.

4. Создайте [Application load balancer](https://cloud.yandex.com/en/docs/application-load-balancer/) для распределения трафика на веб-сервера, созданные ранее. Укажите HTTP router, созданный ранее, задайте listener тип auto, порт 80.

Протестируйте сайт
`curl -v <публичный IP балансера>:80` 

### Мониторинг
Создайте ВМ, разверните на ней Zabbix. На каждую ВМ установите Zabbix Agent, настройте агенты на отправление метрик в Zabbix. 

Настройте дешборды с отображением метрик, минимальный набор — по принципу USE (Utilization, Saturation, Errors) для CPU, RAM, диски, сеть, http запросов к веб-серверам. Добавьте необходимые tresholds на соответствующие графики.

### Логи
Cоздайте ВМ, разверните на ней Elasticsearch. Установите filebeat в ВМ к веб-серверам, настройте на отправку access.log, error.log nginx в Elasticsearch.

Создайте ВМ, разверните на ней Kibana, сконфигурируйте соединение с Elasticsearch.

### Сеть
Разверните один VPC. Сервера web, Elasticsearch поместите в приватные подсети. Сервера Zabbix, Kibana, application load balancer определите в публичную подсеть.

Настройте [Security Groups](https://cloud.yandex.com/docs/vpc/concepts/security-groups) соответствующих сервисов на входящий трафик только к нужным портам.

Настройте ВМ с публичным адресом, в которой будет открыт только один порт — ssh.  Эта вм будет реализовывать концепцию  [bastion host]( https://cloud.yandex.ru/docs/tutorials/routing/bastion) . Синоним "bastion host" - "Jump host". Подключение  ansible к серверам web и Elasticsearch через данный bastion host можно сделать с помощью  [ProxyCommand](https://docs.ansible.com/ansible/latest/network/user_guide/network_debug_troubleshooting.html#network-delegate-to-vs-proxycommand) . Допускается установка и запуск ansible непосредственно на bastion host.(Этот вариант легче в настройке)

Исходящий доступ в интернет для ВМ внутреннего контура через [NAT-шлюз](https://yandex.cloud/ru/docs/vpc/operations/create-nat-gateway).

### Резервное копирование
Создайте snapshot дисков всех ВМ. Ограничьте время жизни snaphot в неделю. Сами snaphot настройте на ежедневное копирование.

---
# Решение

## Инфраструктура  
Согласно условию задания для развертывания виртуальных машин использую Terraform.  
Сразу разворачиваю все необходимые виртуальные машины минимальной конфигурации.  
![alt text](https://github.com/masterchoo495/diplom/blob/main/img/tf1.png)  

![alt text](https://github.com/masterchoo495/diplom/blob/main/img/tf2.png)  

Развернутые виртуальные машины  
![alt text](https://github.com/masterchoo495/diplom/blob/main/img/cloud-vm.png)  

Мною выбран вариант установки и запуска ansible непосредственно на bastion host. Через cloud-init скрипты в момент развертывания инфраструктуры я сразу создаю нужные плейбуки на бастионном хосте и далее с него же буду их запускать для установки и настройки инфраструктуры.  

Проверка версии ansible, содержимого файла inventory и наличия плейбуков 
![alt text](https://github.com/masterchoo495/diplom/blob/main/img/ansible.png)  

Проверка доступности виртуальных машин  
![alt text](https://github.com/masterchoo495/diplom/blob/main/img/ansible-ping.png)  

### Сайт  
На этапе выше были созданы две виртуальные машины vm-web1 и vm-web2 в разных зонах доступности для установки nginx  

Устанавливаю на них nginx через ansible  
![alt text](https://github.com/masterchoo495/diplom/blob/main/img/install-nginx.png)  

Настройка балансировщика  

1. Создайте Target Group, включите в неё две созданных ВМ  
![alt text](https://github.com/masterchoo495/diplom/blob/main/img/target-group.png)  

2. Создайте Backend Group, настройте backends на target group, ранее созданную. Настройте healthcheck на корень (/) и порт 80, протокол HTTP  
![alt text](https://github.com/masterchoo495/diplom/blob/main/img/backend-group.png)  

2. Создайте HTTP router. Путь укажите — /, backend group — созданную ранее  
![alt text](https://github.com/masterchoo495/diplom/blob/main/img/http-router.png)  

4. Создайте Application load balancer для распределения трафика на веб-сервера, созданные ранее. Укажите HTTP router, созданный ранее, задайте listener тип auto, порт 80  
![alt text](https://github.com/masterchoo495/diplom/blob/main/img/alb.png)  

Healthcheck  
![alt text](https://github.com/masterchoo495/diplom/blob/main/img/healthcheck.png)  

Протестируйте сайт: `curl -v <публичный IP балансера>:80`  
![alt text](https://github.com/masterchoo495/diplom/blob/main/img/check-balancer.png)  

Правлю выводимое по умолчанию сообщение при обращении к nginx в /var/www/html/index.nginx-debian.html на vm-web1 и vm-web2 для наглядности работы балансировщика.  
Теперь, обновляя страницу в браузере, мы видим поочередное обращение на vm-web1 и vm-web2  
![alt text](https://github.com/masterchoo495/diplom/blob/main/img/nginx1.png)  
![alt text](https://github.com/masterchoo495/diplom/blob/main/img/nginx2.png)  

### Мониторинг  
Установка Zabbix Server на созданную ранее vm-zabbix через ansible  
![alt text](https://github.com/masterchoo495/diplom/blob/main/img/install-zabbix.png)  

Переход по http://158.160.69.173  
![alt text](https://github.com/masterchoo495/diplom/blob/main/img/zabbix-apache.png)  

Переход по http://158.160.69.173/zabbix и завершение настройки  
![alt text](https://github.com/masterchoo495/diplom/blob/main/img/zabbix-web.png)  

Веб-интерфейс Zabbix Server  
![alt text](https://github.com/masterchoo495/diplom/blob/main/img/zabbix-server.png)  

Установка Zabbix Agent  
![alt text](https://github.com/masterchoo495/diplom/blob/main/img/install-zabbix-agent.png)  

Настроенные дашборды  
![alt text](https://github.com/masterchoo495/diplom/blob/main/img/zabbix-dash.png)  

### Логи  
Установка Elasticsearch на созданную ранее vm-elastic через ansible  
![alt text](https://github.com/masterchoo495/diplom/blob/main/img/install-elastic.png)  

Проверка Elasticsearch  
![alt text](https://github.com/masterchoo495/diplom/blob/main/img/elastic-check.png)  

Установка filebeat на на vm-web1 и vm-web2 через ansible  
![alt text](https://github.com/masterchoo495/diplom/blob/main/img/install-filebeat.png)  

Установка Kibana на созданную ранее vm-kibana через ansible  
![alt text](https://github.com/masterchoo495/diplom/blob/main/img/install-kibana.png)  

Проверка Kibana  
![alt text](https://github.com/masterchoo495/diplom/blob/main/img/kibana-web.png)  

Настраиваю
![alt text](https://github.com/masterchoo495/diplom/blob/main/img/kibana-int.png)  

И проверяю наличие событий 
![alt text](https://github.com/masterchoo495/diplom/blob/main/img/kibana-web2.png)  

### Сеть  
Созданная VPC  
![alt text](https://github.com/masterchoo495/diplom/blob/main/img/vpc.png)  

Созданные Security Groups  
![alt text](https://github.com/masterchoo495/diplom/blob/main/img/sec-groups.png)  

### Резервное копирование  
Расписание снапшотов  
![alt text](https://github.com/masterchoo495/diplom/blob/main/img/snap-schedule.png)  

Создавшиеся по расписанию снимки   
*На момент сдачи работы почему-то перестали создаваться снапшоты по расписанию (хотя раннее при проверке создавались). Пробовал пересоздавать расписание, менять cron-выражение, не помогло. Буду решать этот вопрос с саппортом Яндекса в будний день (в выходные дни на моем тарифном плане поддержку не оказывают).*

