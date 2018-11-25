# asg_swarm
Test packer/terraform  roles for aws swarm cluster


Часть 1 :
Для того чтобы собрать свой образ  выполняем 

cd packer

packer build ubuntu_ami.json

( предварительно вписав свои ключи к амазону  в ubuntu_ami.json)

{
  "variables": {
    "aws_access_key": "AKIAJKDC********",
    "aws_secret_key": "OC/MJh*******ZS9P1*****rP4r3T1v"
  },


-----------------------------------------
Часть 2 :

для Запуска swarm - кластера заходим в папку terraform 

cd terraform

правим main.tf   ,  где указываем  ключи к амазону 

provider "aws" {
  region     = "eu-central-1"
  access_key = "AKIAJ*******H4A"
  secret_key = "OC/MJh************17egArP4r3T1v"
}


и количество  инстансов под воркеры 

locals {
  asg_name_count   = "2"
}

а так же Айди  образа который мы собрали в первой части 
( посмотреть или в веб морде в разделе AMIs , или в выводе резултатов деяний в части 1 )

resource "aws_launch_configuration" "as_conf" { 
  
  image_id      = "ami-0ef3340cffa705c4b"           <-----  оно 

  instance_type = "t2.micro" 




после чего запускаем  

terraform plan -out tfplan


terraform apply tfplan




-------------------------------  описание алгоритма работы  ---------------------

Часть 1: 

Образ собирается на осонове ubuntu-xenial-16.04.
При зборке запускается  provisioners   - scripts/postinstall.sh , в котором запускается ряд действий 
- Добавление официального докер репозитория и установка  Докер 
- установка необходимых нам утилит   awscli ,  jq 
- (можно убрать) создание пользователя devops с ключем 

Так же копируем "туды"  файл  swarm.sh - который мы добавим в крон чтобы он исполнялся каждую минуту.


Часть 2: 

С помощью terraform мы создали 2  Auto Scaling Groups (asg).
в одной из них живет одна "swarma manager node" 
в другой  мы вручную указываем  желаемое количество "swarma worker node"

В процессе старта на Менеджер ноде генерится приватный ключ который мы закидуем какому либо пользователю 
( я закинул тупо  РУТ-у , т.к это тест  и о красоте и безопасности речи не идет )
публичные  ключи засовываем на worker-ноды  пользователю  swarm 

Инициализируется  кластер docker swarm init.

Так же на Менеджер-ноде мы  в Крон добавляем скрипт  swarm.sh  и запускаем каждую минуту 




------------------------------
Скрипт swarm.sh    : 

С помощью добавленной  в образ  утилиты  awscli   он долбится   в "воркер-Автоскейлинг групу"( имеется ввиду  через api амазона) , выдирает оттуда  АйДи
инстансов ,  потом с етими АйДи  долбится в инстансы  и выдираейт  АйПи адреса всех воркеров из автоскейлинг группы 

собственно вот : 
          
          function get_nodes()   {

for i in `aws --region=eu-central-1 autoscaling describe-auto-scaling-groups --auto-scaling-group-names terraform-asg-node | jq '.AutoScalingGroups[].Instances[].InstanceId' -r`; do aws --region=eu-central-1 ec2 describe-instances --instance-ids $i | jq '.Reservations[].Instances[].NetworkInterfaces[].PrivateIpAddress ' -r; done

                       }


Далее  он сравнивает информацию из  вывода команды  docker node ls  и 

- Если в воркер-Автойскейлинг группе есть инстансы которых нету в кластере  swarm -- тогда скрипт идет туда ssh - ем  и выполняет команду добавления в кластер 
- Если есть ноды кластера в состоянии down  - удаляем их из кластера 



=======================================================

как то так , но работает  :) 