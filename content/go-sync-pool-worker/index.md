---
title: "Golang sync.Pool And workers"
date: 2022-07-09T16:47:58+03:00
# weight: 1
# aliases: ["/first"]
categories: ["Work", "Go"]
tags: ["go"]
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

Привет, `%username%`!

Предположим, что нам надо перекидывать в рутине данные между `io.ReadCloser` и `io.WriteCloser` при этом перекидывать их надо на каждый реквест, пока они оба не закрыты

Логично предположить, что первым этапом будет:

```go
var r io.ReadCloser
var w io.WriteCloser
go func() {
	defer r.Close()
	defer w.Close()
	_, err := io.Copy(r, w)
	if err != nil {
		return
	}
}()
```


Казалось бы: есть штатная библиотека, она плохого не посоветует - бери и пользуйся.

Да, пока таких рутин немного, ничего плохого не произойдет, но, если мы заглянем в `io.Copy`, мы увидим, что он передает управление в `io.copyBuffer` и при этом буффер равен nil, а в коде `io.copyBuffer` 

```go
	if buf == nil {
		size := 32 * 1024
		if l, ok := src.(*LimitedReader); ok && int64(size) > l.N {
			if l.N < 1 {
				size = 1
			} else {
				size = int(l.N)
			}
		}
		buf = make([]byte, size)
	}
```

Т.е. каждый раз при вызове `io.Copy` будет аллоцировано до 32KB. Не то что бы это было много, пока у нас не много подобных реквестов. Но не забываем, что 1) аллокация требует времени 2)То, что было ранее аллоцированно не освобождается мгновенно (и даже не за один проход GC)

А теперь давайте усложним: представим что у нас стабильные 1Krps - в секунду алллоцируется 32Mb. GC не успеевает полностью убирать. Погуглим\яндексим и обнаружим такую вешь как `sync.Pool` - позволяет нам избежать излишних аллокаций, путем переиспользования ранее аллоцированных объектов.Вырисовывается вот такой код:

```go
type BlaBla struct {
	//something
	p sync.Pool
}

func NewBlaBla() *BlaBla {
	retutn &BlaBla{
		p := sync.Pool{New: func() interface{} { return make([]byte, 32*1024) }
	}
}
//....
//Some other code
//...

var r io.ReadCloser
var w io.WriteCloser
go func() {
	defer r.Close()
	defer w.Close()
	buf := (blaBla.p.Get()).([]byte)
	defer blaBla.p.Put(buf)
	_, err := io.CopyBuffer(r, w, buf)
	if err != nil {
		return
	}
}()

```
Аллокаций уже гораздо меньше и в целом решение более щадящее по памяти. Короче - все достоинства sync.Pool со всеми недостатками, а именно: иногда приходит GC и убивает нафиг всё, что положено в Pool. На этом можно и оставновиться, но мы пойдем дальше.

Представим, что у вас есть стабильные 30000 реквестов, соответсвенно стабильно живет 30000 такиx рутин, но время жизни у них короткое, к примеру, и вместо умерших рождаются новые. Снова аллокация (да, на горутину тоже аллоцируется место), снова вот это всё. Как быть?

```go
type worker struct {
	start chan struct{}
	end func()
	r io.ReadCloser
	w io.WriteCloser
	buf []byte
}

func newWorker() interface{} {
	w := &worker{
		start: make(chan struct{})
		buf: make([]byte, 32*1024)
	}
	go func() {
		for {
			<- w.start
			w.process()
			w.r = nil
			w.w = nil
			w.end()
			w.end = nil
		}
	}()
	return w
}

func (w *worker) process() {
	defer w.r.Close()
	defer w.w.Close()
	io.CopyBuffer(w.r, w.w, w.buf)
}

func (w *worker) Start(w io.WriteCloser, r io.ReadCloser, end func()) {
	w.w = w
	w.r = r
	w.end = end
	w.start <- struct{}{}
}

type BlaBla struct {
	//something
	p sync.Pool
}

func NewBlaBla() *BlaBla {
	retutn &BlaBla{
		p := sync.Pool{New: newWorker }
	}
}
//....
//Some other code
//...

var r io.ReadCloser
var w io.WriteCloser
w := (blaBla.p.Get()).(*worker)
w.Start(w,r, func() { blaBla.p.Put(w)})

```

Таким образом получается пул готовых воркеров, с созданными горутинами, которые только ждут отмашки на старт процесса. 

**И вот тут есть ньюанс! Так-как указатель на наш воркер, даже когда его вернули в пул, есть не только в пуле, но и в живой рутине, то GC никогда (пока жива рутина) не убьет воркера, и мы раз за разом будем доставать одни и те же воркеры, а размер пула (суммарный) будет равен пиковому количеству воркеров**


---
Если у тебя есть вопросы, комментарии и/или замечания – заходи в [чат](https://t.me/pero_legiona_chat), а так же подписывайся на [канал](https://t.me/pero_legiona).
