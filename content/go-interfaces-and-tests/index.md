---
title: "Go Interfaces and Tests"
date: 2022-07-30T11:29:55+03:00
# weight: 1
# aliases: ["/first"]
categories: ["Go","Tutorial"]
tags: ["go","tutorial","interface","unittest", "java"]
type: "post"
author: "VLegio"
description: ""
showToc: false
TocOpen: false
draft: false
hidemeta: false
disableShare: false
# cover:
#     image: "<image path/url>"
#     alt: "<alt text>"
#     caption: "<text>"
#     relative: false
comments: false
---

# О интерфейсах замолвим словечко

Начнем с простого - интерфейс это некое описание поведения. Если удобнее - контракт, который необходимо выполнить объекту, что бы другие объекты\методы\функции могли с ним работать. 
В большинстве языков нужно явно указывать что объект исполняет этот контракт, к примеру на Java:
```java
interface Sayer { //Интерфейс Sayer описывает поведение (на самом деле в Java можно описывать и данные в интерфейсе)
    public String Say();
}

class Say { //Работает с интерфейсом Sayer
    String n;
    Sayer s;
    public Say(String name, Sayer sayer) {
        n = name;
        s = sayer;
    }
    
    public void Talk() {
        System.out.println(n + " say: " + s.Say());
    }
}

class Dog implements Sayer { //Класс собаки, явно указываем что имплементирует интерфейс Sayer
    public String Say() {
        return "wof wof";
    }
}

class Human implements Sayer { //Человек, опять таки явно указываем
    public String Say() {
        return "Damned work!";
    }
}


public class MyClass {
    
    public static void main(String args[]) {
      (new Say("Jack", new Dog())).Talk();
      (new Say("John", new Human())).Talk();
    }
}
```
Результат выполнения:
```
Jack say: wof wof
John say: Damned work!
```

Поиграться можно вот [здесь](https://www.jdoodle.com/online-java-compiler/)

Как видим Java (и многие другие языки) прекрасно работает с интерфейсами, пока классы явно знают что именно они имплементируют. Если же мы, к примеру, уберем у `Human` `implements Sayer` то при попытке выполнения получим вот это:
```
/MyClass.java:34: error: incompatible types: Human cannot be converted to Sayer
      (new Say("John", new Human())).Talk();
                       ^
Note: Some messages have been simplified; recompile with -Xdiags:verbose to get full output
1 error
```

Итого, на этом примере, мы видим, что интерфейсы, сами по себе, довольно интересная штука, они позволяют нам задать контракт и работать со всем, что имплементирует этот контракт, не зная деталей реализации, но во многих языках реализация должна знать какой интерфейс\интерфейсы она имплементирует.

# А как в Go?

А в Go несколько проще. С одной стороны у нас есть дополнительное ограничение - интерфейсы являются контрактом только на поведение, а не на данные. С другой стороны нам не надо указывать какие интерфейсы имплементирует объект.

Давайте повторим наш предыдущий пример на Go

```go
package main

import "fmt"

type Sayer interface {
	Say() string
}

type Human struct{}

func (h Human) Say() string {
	return "Damned work!"
}

type Dog struct{}

func (d Dog) Say() string {
	return "Wof wof!"
}

func Talk(name string, s Sayer) {
	fmt.Printf("%s say: %s\n", name, s.Say())
}

func main() {
	Talk("Jack", Dog{})
	Talk("John", Human{})
}
```

Поиграться [здесь](https://go.dev/play/p/6XG1OEzVh5o)

Как мы видим нет никакого явного указания на имплементирование интерфейсов. В Go проверка на имплементацию интерфейса происходит в runtime и, частично, в compiletime, как в данном случае.

# Где используются интерфейсы в Go?

Если коротко - везде. К примеру, [error](https://pkg.go.dev/builtin#error) это интерфейс вида:
```
type error interface {
	Error() string
}
```
Т.е. любая структура имеющая метод `Error() string` может быть использована как error

# Как происходит определение что объект имплементирует интерфейс?

Если не вдаваться в подкапотные детали, то очень просто, но начать надо издалека.

Каждый тип в Go, в рантайме имеет свое описание в таблице типов, среди прочего там есть таблица методов, её можно, условно представить вот так


|Name|Params|Return|
|:----:|:----:|:----:|
| Read | []byte| int, error|
| Close| | error |
|Seek| int64, int | int64, error|



Для структуры вида:
```go
type RSC struct{}

func (r RSC) Read(b []byte)(int,error){
	return 0, nil
}

func (r RSC) Close() error {
	return nil
}

func (r RSC) Seek(o int64, w int) (int64, error) {
	return 0, nil
}

```

Интерфейс, в свою очередь, тоже структура. Правда не конкретный интерфейс, а в целом, если его упрощенно представить, то это будет выглядеть так

```go 
type Interface struct {
	Name string
	MethodTable *MethodTable
	ObjDescritpion *ObjDescritpion
	Obj unsafe.Pointer
}
```

На этом моменте люди хорошо разбирающиеся в Go достают заточки и идут ко мне домой явно не попить чаю, а с целью прояснить что я очень не правильно передал детали реализации. Однако, конкретные детали нам сейчас не нужны.

Дак вот, что же происходит когда мы пытаемся  передать структуру как интерфейс (привести к интерфейсу).

Если кодом то примерно вот это:
```go
	if Obj.ObjDescritpion.MethodTable.IsContain(Interface.MethodTable) {
		return true
	} else {
		return false
	}
```

А если на примере таблиц, то, возьмем интерфейс io.ReadСloser, его таблица методов будет выглядеть вот так:
|Name|Params|Return|
|:----:|:----:|:----:|
| Read | []byte| int, error|
| Close| | error |

Дальше мы смотрим: если каждая строка из этой таблицы полностью совпадает с какой-либо либо строкой из таблицы объекта - объект  имплементирует интерфейс.


# А что по использованию?

Интерфейсы надо использовать, на самом деле почти всегда, есть, даже, такое правило: 
>Возвращаем структуры, принимает интерфейсы

Cразу скажу, не надо слепо ему следовать, но в общем и целом оно верно.

Зачем использовать? Давайте разберем простенький пример:

```go
func WordCount(f *os.File) (map[string]int, err) {
	//Вычитывается файл по словам, составляется мапа в которой у каждого слова указано количество вхождений в файл
}
```
И тут возникает ряд вопросов.
* А если у нас не файл, а, к примеру TCPConnect
* А как это тестировать?

Начну со второго, более важного вопроса: создать файл на ФС, в тестах указать до него путь, открыть и так далее... Короче, превратить юнит тест в интеграционный.
Звучит отвратительно, поэтому мы поменяем конкретный тип на интерфейс

```go
func WordCount(r io.Reader) (map[string]int, err) {
	//Вычитывается файл по словам, составляется мапа в которой у каждого слова указано количество вхождений в файл
}
```

Теперь не только из файла, но и из всего, что имплементирует io.Reader мы можем подсчитать количесво вхождений слов, будь это хоть TCPConnect хоть буффер байтов, и, тем самым, мы значительно упростили себе тестирование оставив его в рамках юнит-тестов, так-как нам не обязательно создавать файл, а достаточно сделать как-то так:

```go
	r := bytes.NewReader([]byte("abc abc cba d d d")
	res, err := WordCount(r)
	if err != nil {
		t.Fail(err)
	}
	if res["abc"] != 2 {
		t.Fail()
	}
	if res["cba"] != 1 {
		t.Fail()
	}
	if res["d"] != 3 {
		t.Fail()
	}
```


Либо, другой пример:


```go

type User struct {
	ID int64
	Name string
	IsAdmin bool
}

type UserRepository interface {
	GetUser(id int64) (*User, error)
}

type UserService struct {
	repository UserRepository
}

func (us *UserService) IsAdminUser(id int64) (bool, error) {
	user, err := us.repository.GetUser(id)
	if err != nil {
		return false, err
	}
	return user.IsAdmin, nil
}

```

Благодаря тому, что `UserService` работает не с реализацией, а с интерфейсом мы можем использовать любую реализацию этого интерфейса. К примеру в случае реальной работы он будет работать с реализацией которая ходит в постгресс, а в случае тестов с имплементацией - моком, к примеру вот такой:

```go
type MockUserRepository struct{}{}

func (MockUserRepository) GetUser(id int64) (*User, error) {
	return &User{ID: id, IsAdmin: true}, nil
}
```
Что нам позволит тестировать код UserService без зависимости от базы данных. 

Вторым плюсом (и довольно важным!) использования интерфейсов в данном случае является инверсия зависимостей, теперь не UserService (более высокоуровненый код) зависит от имплементации репозитария, а репозитарий должен имплементировать интерфейс объявленный UserService.

На этом на сегодня всё. Как говорят в старых фильмах: *ту би континуэд...* =)

---
Если у тебя есть вопросы, комментарии и/или замечания – заходи в [чат](https://t.me/cursor_legiona_chat), а так же подписывайся на [канал](https://t.me/cursor_legiona).
