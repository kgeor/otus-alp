# Управление процессами
Перед началом скопируем все скрипты с общей директории ВМ в домашнюю (*важно для второй части с ionice не использовать примонтированную общую папку*)
`cp /vagrant/*.sh ~`

## Запуск конкурирующих процессов с разным `nice`
За основу возьмем рекурсивную функцию, подсчитывающую количество вариантов построения лестницы из n кубиков (каждый вышележащий ряд должен быть меньше нижележащего).
Скрипт `run_nice.sh` запускает в background-е два идентичных процесса (`n=50`) с разным показателем `nice`.
```
[root@rocky9 ~]# bash run_nice.sh 50
Waiting..... Results will be printed
Number of options for building a staircase of 50 cubes: 3658

real    0m24.985s
user    0m16.814s
sys     0m0.072s
Result for nice = -15
Number of options for building a staircase of 50 cubes: 3658

real    0m33.924s
user    0m16.736s
sys     0m0.070s
Result for nice = 0
```
По результатам выполнения видим, что процесс с более высоким показателем `nice` затратил значительно больше времени, так как чаще был вынужден уступать ресурсы ЦП более приоритетным процессам.
## Запуск конкурирующих процессов с разным `ionice`
Для оценки временных затрат в данном случае будем использовать копирование бинарных файлов равного размера size МБ со случайным содержимым.
Для size = 256 получаем:
```
[root@rocky9 ~]# bash run_ionice.sh 256
Creating random files of 256 Mb size
Copying generated files with different ionice classes
Waiting..... Results will be printed

real    0m6.745s
user    0m0.073s
sys     0m1.176s
Result for ionice c=1

real    0m14.450s
user    0m0.255s
sys     0m0.983s
Result for ionice c=2
```
Результаты показывают, что процесс с более приоритетным классом ionice 1 затратил меньше времени на выполнение операций ввода/вывода.