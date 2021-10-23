# Informe lab 3

- Fuentes, Tiffany
- Renison, Iván
- Vispo, Valentina Solange

---

**[README](README.md) | [CONSIGNA](consigna.md) | [To Do](todo.md)**

---

# Contenido

- [Instalación](#instalación)
    - [QEMU](#qemu)
- [¿Cómo correrlo?](#cómo-correrlo)
    - [Manejo básico de qemu](#manejo-básico-de-qemu)
- [Parte I: Estudiando el planificador de xv6](#parte-i-estudiando-el-planificador-de-xv6)
    - [Pregunta 1](#pregunta-1)
        - [Respuesta 1](#respuesta-1)
    - [Pregunta 2](#pregunta-2)
        - [Respuesta 2a](#respuesta-2a)
        - [Respuesta 2b](#respuesta-2b)
- [Parte II: Cómo el planificador afecta a los procesos](#parte-ii-cómo-el-planificador-afecta-a-los-procesos)
    - [Automatizado de testeos](#automatizado-de-testeos)
        - [`AutoMed.sh`](#automedsh)
        - [`Extraer_archivos.sh`](#extraer_archivossh)
    - [Mediciones](#mediciones-rr)
- [Parte III: Rastreando la prioridad de los procesos](#parte-iii-rastreando-la-prioridad-de-los-procesos)
    - [MLFQ regla 3: rastreo de prioridad y asignación máxima](#mlfq-regla-3-rastreo-de-prioridad-y-asignación-máxima)
    - [MLFQ regla 4: descenso y ascenso de prioridad](#mlfq-regla-4-descenso-y-ascenso-de-prioridad)
- [Parte IV: Implementando MLFQ](#parte-iv-implementando-mlfq)
    - [MLFQ regla 1: correr el proceso de mayor prioridad](#mlfq-regla-1-correr-el-proceso-de-mayor-prioridad)
    - [MLFQ regla 2: round-robin para procesos de misma prioridad](#mlfq-regla-2-round-robin-para-procesos-de-misma-prioridad)
    - [Mediciones](#mediciones-mlfq)
    - [Respuesta 3](#respuesta-3)
- [Puntos estrellas](#puntos-estrellas)
    - [Quantum distinto por prioridad](#quantum-distinto-por-prioridad)
    - [Priority Boost de OSTEP](#priority-boost-de-ostep)
- [Mediciones MLFQ final](#mediciones-mlfq-final)

---

# Instalación

## QEMU

```bash
sudo apt-get update -y
```

```bash
sudo apt-get install -y qemu-system-i386
```

# ¿Cómo correrlo?

`cd xv6-modularized && make clean && make CPUS=1 qemu-nox`

Para correr las benchmarks se debe escribir:

`cpubench &`

`iobench &`

Y para matarlo: `kill pid`

## Manejo básico de qemu

- Para listar los procesos dentro de `xv6` hacer `<CRTL-p>`.

- Salir de QEMU: `<CTRL-a> x`.

- Para iniciar QEMU CON pantalla VGA: `make qemu`.

- Para iniciar QEMU SIN pantalla VGA: `make qemu-nox`.

---

# Parte I: Estudiando el planificador de xv6

## Pregunta 1

1. Analizar el código del planificador y responda:
   a. ¿Qué política utiliza `xv6` para elegir el próximo proceso a correr?

> Pista: `xv6` nunca sale de la función scheduler por medios "normales".

### Respuesta 1

La política que utiliza el `xv6` es **round robin**, que permite que los procesos corran consecutivamente durante un tiempo determinado denominado *quantum*.

```c
void
scheduler(void)
{
  // [...]
  for(;;){
    // [...]
    // Loop over process table looking for process to run.
    acquire(&ptable.lock);

    // Itera sobre todos los procesos en el orden de la tabla de procesos
    for(p = ptable.proc; p < &ptable.proc[NPROC]; p++){
      // Luego checkea si es "corrible"
      if(p->state != RUNNABLE)
        continue;

      // Switch to chosen process.
      // [...]
      // Process is done running for now.

      // It should have changed its p->state before coming back.
      c->proc = 0;
    }
    release(&ptable.lock);
  }
  // La expresión ";;" es equivalente a true => es un for infinito
  // Por lo tanto, siempre vuelve a comenzar con la iteración sobre la tabla.
}
```

Referencias:

- [cs537p2b_xv6Scheduler.pdf](http://pages.cs.wisc.edu/~kzhao32/projects/cs537p2b_xv6Scheduler.pdf)

## Pregunta 2

  2. Analizar el código que interrumpe a un proceso al final de su *quantum* y responda:
   
      a. ¿Cuánto dura un *quantum* en `xv6`?
   
      b. ¿Hay alguna forma de que a un proceso se le asigne menos tiempo?

> Pista: Se puede empezar a buscar desde la system call `uptime`.

### Respuesta 2a

Cada vez que hay un timer interrupt, el proceso que está corriendo le entrega el control al kernel, lo que quiere decir que el *quantum* dura el mismo tiempo que existe entre timer interrupts. En el archivo `lapic.c` se indica que el timer cuenta `10000000` ticks para hacer un timer interrupt, estos ticks dependen de la velocidad del procesador.

Ejemplo: En un procesador con una velocidad de `900MHz` se producen 900 millones de ticks por segundo, lo que quiere decir que produce `10000000` de ticks en aproximadamente 0,0111 segundos que es una centésima de segundo.

En el archivo `lapic.c`:

```c
// The timer repeatedly counts down at bus frequency
// from lapic[TICR] and then issues an interrupt.
// If xv6 cared more about precise timekeeping,
// TICR would be calibrated using an external time source.
lapicw(TICR, 10000000);
```

### Respuesta 2b

Con el código que tiene `xv6` originalmente no es posible, ya que se le asigna el mismo *quantum* a todos los procesos, pero si es posible modificar el código para darle distintos *quantums* a los procesos.

# Parte II: Cómo el planificador afecta a los procesos

    El tipo de planificador puede influir en cuantos recursos se le asignan a cada proceso. En particular, el planificador *round robin* que viene en `xv6` asigna el mismo *quantum* a todos los procesos, mientras que el planificador MLFQ (Multi Level Feedback Queue) asigna *quantums* distintos a cada proceso dependiendo de su prioridad.

    Es interesante y muy útil, saber como afecta de distinta manera a los procesos de distintos tipos. Para eso, junto con la consigna nos dieron 2 programas para realizar distintas mediciones.

    El programa `cpubench` mide la cantidad de operaciones de punto flotante que puede hacer en una cierta cantidad de ticks del sistema operativo. En particular, las operaciones en `MINTICKS` (definido por defecto en `250`) ticks del sistema operativo, y lo imprime en KFLOPT (Kilo Floating Point Operations Per Tick) (por defecto pone como unidad MFLOPT (mega en lugar de kilo), pero es un error, ya que lo calcula en kilo).

    Los ticks del sistema operativos se obtienen con la llamada al sistema `uptime` y son la cantidad de interrupciones por timer producidos desde el inicio del sistema. Esto causa que si se hace que el timer sea más chico, las mediciones de `cpubench` den menos, porque obviamente en menos tiempo se hacen menos cosas, pero, tiene la ventaja de que no depende de la velocidad del procesador, ya que por más que cambie la velocidad a la que el procesador ejecuta las instrucciones, la cantidad de instrucciones ejecutadas entre una interrupción y la otra son las mismas.

    El otro programa que dieron es `iobench` que mide la cantidad de escrituras y lecturas de un archivo que puede hacer en `MINTICKS` ticks del sistema operativo, y las imprime en IOP`MINTICKS`T (Input Output Operations Per `MINTICKS` Ticks).

    Nosotros decidimos modificar un poco estos programas, para hacer que en lugar de imprimir la cantidad de operaciones por cierta cantidad de ticks, imprima la cantidad de operaciones y la cantidad de ticks por separado, para hacer nosotros la división, y evitar la perdida de error por el redondeo de la división entera (en `iobench` habían hecho que se imprima en `MINTICKS` ticks posiblemente para evitar un poco eso, pero nos pareció mejor directamente imprimir todo).

## Automatizado de testeos

    En la consigna se pide ejecutar en distintas combinaciones estos programas con el planificador por defecto y con el nuestro, para poder compararlos. Hacer eso a mano es bastante trabajo, así que nosotros decidimos intentar automatizarlo un poco.

    Para automatizarlo hicimos 2 scripts en la carpeta `Automatizar_mediciones`, uno que se encarga de ejecutar todos los test y guardar los resultados en archivos dentro de `xv6`, y otro que se encargue de extraer de `xv6` esos archivos.

    A continuación una explicación de como funciona cada uno de ellos:

### AutoMed.sh

    Este es el script que se encarga de ejecutar los tests, redirigiendo las salidas a archivos dentro de `xv6`.

    Lo que hace es tener una lista de los comandos a ejecutar en cada test y para cada uno ejecuta `xv6` durante un cierto tiempo pasándole a la entrada estándar el comando de este test.

### Extraer_archivos.sh

    Este es el script que se encarga de extraer los archivos de `xv6`.

    Lo que hace es tener una lista de los archivos que tiene que extraer, y para cada uno ejecuta qemu pasándole a la entrada estándar `cat nombre_del_archivo`, y redirigiendo la salida a un archivo del mismo nombre en Linux, quitándole las primeras 14 lineas, que son los que se imprime hasta el `cat`, y los últimos 2 caracteres que son el `$ ` que se imprime después.

    Para generar los comandos que hay que ejecutar y los nombres de los archivos que hay que extraer usamos un pequeño archivo de haskell `Generador_listas.hs`, en donde `comandos_test` son los comandos y `archivos_test` los archivos.

    Para usar los scripts hay que, desde la carpeta `xv6-modularized`, después de haber hecho un `make qemu` para que se compile `xv6`, hacer `bash ../Automatizar_mediciones/AutoMed.sh` para correr los test y después `bash ../Automatizar_mediciones/Extrear_archivos.sh` para extraer los archivos.

## Mediciones RR

A continuación presentamos una tabla que representa cada caso de las mediciones realizadas:


| Caso |     Descripción      | 
|------|----------------------|
|   0  | 1 iobench            |
|   1  | 1 iobench 1 cpubench |
|   2  | 1 iobench 2 cpubench |
|   3  | 1 cpubench           |
|   4  | 1 cpubench 2 iobench |
|   5  | 2 cpubench 2 iobench |
|   6  | 2 cpubench           |
|   7  | 2 iobench            |

Todos los casos de la tabla se midieron en el planificador original de `xv6` usando el *quantum* normal, 10 veces menor y 100 veces menor. A pesar de que en la consigna piden realizar la medición con un quantum 1000 veces menor decidimos no realizarlo ya que el `xv6` se vuelve tan lento que la mayoria de las mediciones devuelven 0.

Cada vez que eliminabamos un 0 del *quantum* para reducir su tiempo, en los archivos `cpubench` e `iobench` se aumentaba por un cero la variable `MINTICKS` para que de esta manera se obtuviera una cantidad similar de resultados en todas las mediciones. A continuación presentamos los gráficos correspondientes a cada *quantum*.

* *Quantum* normal:

![quantum-normal-rr](/imagenes/rrnormal.jpg "round robin quantum normal")

* *Quantum* 10 veces menor:

![quantum-10-menor-rr](/imagenes/rr10less.jpg "round robin quantum 10 veces menor")

* *Quantum* 100 veces menor:

![quantum-100-menor-rr](/imagenes/rr100less.jpg "round robin quantum 100 veces menor")


# Parte III: Rastreando la prioridad de los procesos

Habiendo visto las propiedades del planificador existente, reemplazarlo con un planificador MLFQ de tres niveles. Esto se debe hacer de manera gradual, primero rastrear la prioridad de los procesos, sin que esto afecte la planificación.

1. Agregue un campo en `struct proc` que guarde la prioridad del proceso (entre `0` y `NPRIO-1` para `#define NPRIO 3` niveles en total) y manténgala actualizada según el comportamiento del proceso:

    * MLFQ regla 3: Cuando un proceso se inicia, su prioridad será máxima.

    * MLFQ regla 4:
  
        * Descender de prioridad cada vez que el proceso pasa todo un *quantum* realizando cómputo.
  
        * Ascender de prioridad cada vez que el proceso bloquea antes de terminar su *quantum*.
        > Nota: Este comportamiento es distinto al del MLFQ del libro.

2. Para comprobar que estos cambios se hicieron correctamente, modifique la función `procdump` (que se invoca con `CTRL-P`) para que imprima la prioridad de los procesos. Así, al correr nuevamente `iobench` y `cpubench`, debería darse que `cpubench` tenga baja prioridad mientras que `iobench` tenga alta prioridad.

## MLFQ regla 3: rastreo de prioridad y asignación máxima

* El valor **máximo de la prioridad** es el valor `0`,
* y el valor `NPRIO` es la **prioridad mínima**.

Explicación de los archivos:

* `trap.h`: define los "traps" y los *interrupts del kernel*.

Entre ellos está el siguiente:

```c
#define IRQ_TIMER        0
```

Este define el interrupt llamado periódicamente por el hardware que usa el scheduler para medir los *quantums*.

* `trap.c`: este implementa todas las traps, entre ellas las **syscalls** (con la función de su mismo nombre, `syscall()`) y los **interrupts del timer** (con la función `yield()`).

Para asegurar que los procesos se inicien con la prioridad más alta, en la función `allocproc` (que se encarga de inicializar el estado requerido del proceso para poder ejecutarlo en el kernel) del archivo `proc.c`, para un proceso `p` se inicializa su prioridad como `p->priority = 0`.

## MLFQ regla 4: descenso y ascenso de prioridad

Donde el **descenso de prioridad** ocurre en el `yield()`

```c
// Force process to give up CPU on clock tick.
// If interrupts were on while locks held, would need to check nlock.
if(myproc() && myproc()->state == RUNNING &&
    tf->trapno == T_IRQ0+IRQ_TIMER)
  yield();
```

Y el **ascenso de prioridad** ocurre en el `sleep()` ya que es donde se cambia de estado de `RUNNING` a `SLEEPING` y esto indica que el proceso pasa a estar **bloqueado**, como lo indica la regla 4.

# Parte IV: Implementando MLFQ

Finalmente implementar la planificación propiamente dicha para que nuestro `xv6` utilice MLFQ.

1. Modifique el planificador de manera que seleccione el próximo proceso a planificar siguiendo las siguientes reglas:
   
    * MLFQ regla 1: Si el proceso `A` tiene mayor prioridad que el proceso `B`, corre `A`. (y no `B`)
    * MLFQ regla 2: Si dos procesos `A` y `B` tienen la misma prioridad, corren en *round-robin* por el *quantum* determinado.

2. Repita las mediciones de la segunda parte para ver las propiedades del nuevo planificador.

3. Para análisis responda: ¿Se puede producir `starvation` en el nuevo planificador? Justifique su respuesta.

> Importante: Mucho cuidado con el uso correcto del mutex `ptable.lock`.

## MLFQ regla 1: correr el proceso de mayor prioridad

Para poder facilitar el manejo de las prioridades dicidimos usar colas, para hacer esto cambiamos el `struct ptable` del archivo `proc.c` que tiene la estructura de la tabla de procesos, para que contenga dos arreglos de punteros a procesos, `queue_first` que contiene los primeros procesos en la cola de cada prioridad, y `queue_last` que contiene los últimos procesos de la cola. También modificamos el `struct proc` que contiene la estructura de los procesos para añadir un puntero `next_proc` el cual va a apuntar al siguiente proceso en la cola.

Al inicializarse `xv6` la memoria se inicializa en 0, por lo que las colas se inicializan en 0, luego al inicializarse un proceso en `userinit`, esta función hace una llamada a `allocproc` que asigna la prioridad más alta al proceso, y luego se encola en la cola correspondiente. En el planificador se realiza un ciclo para encontrar el proceso de la prioridad más alta revisando el primer proceso de la cola de cada prioridad, dado que las colas solo tienen procesos que están en estado `RUNNABLE`, con ver si el primer elemento de la cola existe es suficiente para saber si hay procesos de dicha prioridad por correr. El ciclo comienza revisando la cola de prioridad más alta (prioridad 0), por lo que siempre se va a correr el proceso de mayor prioridad.

Para asegurarnos de que en las colas solo haya procesos en estado `RUNNABLE`, luego de correr cada proceso se saca de su cola haciendo `dequeue`, de esta forma si el proceso pasa a cualquier otro estado sólo se vuelve a encolar cuando pasa nuevamente a estado `RUNNABLE`, como por ejemplo en `wakeup` donde el proceso pasa de estado `SLEEP` a `RUNNABLE`.

Lo más importante de la implementación con colas es que mejora ligeramente el rendimiento, ya que a diferencia del planificador original de `xv6` no hay que recorrer la tabla completa de procesos para encontrar uno para ejecutar.

## MLFQ regla 2: round-robin para procesos de misma prioridad

Con la implementación que tenemos siempre se va a correr el proceso de prioridad más alta que este en estado `RUNNABLE`, luego de ejecutarse este proceso se van a revisar las colas nuevamente para buscar otro proceso por correr, en caso de que no haya un proceso de prioridad más alta que el que se ejecutó anteriormente, se seguiran ejecutando los procesos de la misma cola de prioridad de el proceso anterior, de esta forma los procesos de la misma prioridad se corren en *round-robin* por el *quantum* establecido.

Es importante observar que en esta implementación siempre que un proceso consuma su *quantum* y ejecute `yield()` para ceder el CPU, se baja la prioridad del proceso.

## Mediciones MLFQ

En este punto se realizaron las mismas mediciones que se realizaron anteriormente con el planificador original de `xv6`, también se omitieron las mediciones del *quantum* 1000 veces menor por el mismo motivo. Para conocer que medición representa cada caso referirse a la [tabla](#mediciones-rr) anterior. 

* *Quantum* normal:

![quantum-normal-mlfq](/imagenes/mlfqnormal.jpg "MLFQ quantum normal")

* *Quantum* 10 veces menor:

![quantum-normal-rr](/imagenes/mlf10less.jpg "MLFQ quantum 10 veces menor")

* *Quantum* 100 veces menor:

![quantum-normal-rr](/imagenes/mlf100less.jpg "MLFQ quantum 100 veces menor")

Similarmente a lo que sucedia con el planificador *round-robin* en los casos en que se reduce el *quantum* las mediciones de `cpubench` son tan bajas que prácticamente no se pueden observar en los gráficos. También se puede observar que con el *quantum* normal el planificador MLFQ tiene mejores mediciones en cuanto a `iobench` pero que mientras más se reduce el quantum más empeora el desempeño del mismo con respecto al planificador *round-robin*.

## Respuesta 3

Sí, se puede producir `starvation` en el nuevo planificador, porque si hay un proceso largo `IO bound`, o si hay varios procesos IO bound, con la política de ascensión que se implementó cada vez que se bloquea un proceso se le sube la prioridad, es decir que un proceso que devuelva el control al kernel antes de que termine el quantum ya que se bloquea siempre se va a mantener en la prioridad más alta, por lo que los procesos que esten en la prioridad más baja nunca tienen oportunidad de correr.

# Puntos estrellas

- Del planificador:
  
    1. [x] Reemplace la política de ascenso de prioridad por la regla 5 de MLFQ de OSTEP: **Priority boost**.

    2. [x] Modifique el planificador de manera que los distintos niveles de prioridad tengan distintas longitudes de *quantum*.

    3. [ ] Cuando no hay procesos para ejecutar, el planificador consume procesador de manera innecesaria haciendo `busy waiting`. Modifique el planificador de manera que ponga a dormir el procesador cuando no hay procesos para planificar, utilizando la instrucción `hlt`.

    4. [ ] (Difícil) Cuando `xv6` corre en una máquina virtual con **2 procesadores**, la performance de los procesos varía significativamente según cuántos procesos haya corriendo simultáneamente. ¿Se sigue dando este fenómeno si el planificador tiene en cuenta la localidad de los procesos e intenta mantenerlos en el mismo procesador?

    5. [ ] (Muy difícil) Y si no quisiéramos usar los *ticks periódicos del timer* por el problema de *(1)*, ¿qué haríamos? Investigue cómo funciona e implemente un **tickless kernel**.

- De las herramientas de medición:
  
    - [ ] Llevar cuenta de cuánto tiempo de procesador se le ha asignado a cada proceso, con una system call para leer esta información desde espacio de usuario.

## Quantum distinto por prioridad

En el planificador original de `xv6`un *quantum* mide lo mismo que un tick del sistema, el cual esta definido en `lapic.c` y el cual dura 10 millones de ticks del procesador, cada vez que se aumenta el tick de `xv6` es porque ocurrio un timer interrupt. En `trap.c` se encuentra este fragmento de código:

```
// Force process to give up CPU on clock tick.
// If interrupts were on while locks held, would need to check nlock.
  if(myproc() && myproc()->state == RUNNING && tf->trapno == T_IRQ0+IRQ_TIMER)
    yield();
```

Es decir que cada vez que hay un timer interrupt el proceso devuelve el CPU, lo que quiere decir que se terminó su *quantum*. Para poder agregar un *quantum* distinto para cada prioridad habría que modificar esta parte del código.

Decidimos que el *quantum* de cada prioridad sería de la siguiente manera:

| Prioridad | Quantum |
|-----------|---------|
|     0     |  1 tick |
|     1     |  2 ticks|
|     2     |  4 ticks|

Es decir para cada prioridad su *quantum* sería igual a 2^prioridad.

Para poder llevar la cuenta del tiempo (cantidad de ticks) que llevaba cada proceso corriendo en su prioridad actual añadimos un campo al `struct proc` del archivo `proc.h` llamado `ticks_running`. Cada vez que se inicia un proceso el mismo se inicializa con `ticks_running = 0`, luego mientras el proceso se está ejecutando, cada vez que ocurra un timer interrupt se aumenta esta variable en 1 y se revisa si `ticks_running` es mayor o igual a su *quantum* correspondiente y en este caso se hace `yield()` y se devuelve el CPU.

En algunos casos los procesos pueden bloquearse antes de terminar con su *quantum*, lo que quiere decir que no llaman a `yield` por lo que al proceso no se le baja la prioridad, y cuando vuelve a correr en la misma prioridad tiene un *quantum* completo para correr, para que esto no suceda decidimos que solo se reinicia la variable `ticks_running` (es decir se coloca en 0), cuando el proceso hace `yield`, de esta manera si el proceso se bloquea sin haber terminado el cuanto se lleva la cuanta de por cuantos ticks se había ejecutado antes de bloquearse.

Debido a que la única forma que encontramos de llevar la cuenta del tiempo pasado en `xv6` fue utilizando la variable `ticks`, esto quiere decir que no tenemos una precisión muy grande, asi que por ejemplo en caso de que un proceso este corriendo y siempre se bloquee antes de que pase un `tick` nunca haría `yield`, y como la única forma que tenemos de llevar la cuenta del tiempo corrido es utilizando `ticks` la variable `ticks_running` nunca aumentaría, por lo que este proceso siempre quedaría en la prioridad más alta.

Finalmente la parte modificada de `trap.c` quedó de la siguiente manera:

```
// Force process to give up CPU on clock tick.
// If interrupts were on while locks held, would need to check nlock.
if(myproc() && myproc()->state == RUNNING && tf->trapno == T_IRQ0+IRQ_TIMER){
  myproc()->ticks_running++;
  // quantum = 2^priority ticks
  if(1 << myproc()->priority <= myproc()->ticks_running)
    yield();
}
```
Observar que como en `xv6` no tenemos la manera de representar potencias 2^prioridad es equivalente a 1 << prioridad, en donde << se refiere a un logical shift left.

## Priority Boost de OSTEP

En este punto se cambio la implementación anterior del priority boost en el que se asciende la prioridad del proceso cada vez que este se bloquea, a una implementación mas parecida a la del libro OSTEP en la que se asciende la prioridad de todos los procesos a la prioridad más alta cada cierta cantidad de tiempo.

Para hacer esto creamos una función `priority_boost` en el archivo `proc.c` en el cual se recorren todos los procesos en la tabla de procesos y se coloca la prioridad de cada uno en 0 (que es la prioridad más alta). Decidimos definir una constante `BOOSTTIMER` que se encuentra definida en el archivo `param.h` para establecer la cantidad de tiempo que tiene que pasar entre cada priority boost.

Cada vez que se realiza un timer interrupt en `xv6` se aumenta el contador de ticks que son los que llevan la cuenta del tiempo que ha pasado, por eso decidimos que en el archivo `trap.c`, en donde se aumenta la variable ticks , se chequee si ya paso la cantidad de tiempo definido por la constante `BOOSTTIMER`, de esta forma si `ticks % BOOSTTIMER == 0` se hace la llamada a `priority_boost` para ascender la prioridad de los procesos.

Debido a la implementación con colas que manejamos luego de ascender la prioridad de los procesos es importante actualizar el primer y último elemento de cada cola de prioridad, en este caso lo que hacemos es concatenar los procesos de manera que el último proceso de cada cola apunte al primer proceso de la siguiente cola no vacía. A continuación colocamos unas imágenes para que se entienda mejor el proceso.

Colas antes del priority boost:

![queue-before-boost](/imagenes/queue-before-boost.jpg "queues before priority boost")

Colas despues del priority boost:

![queue-after-boost](/imagenes/queue-after-boost.jpg "queues after priority boost")

# Mediciones MLFQ final

Finalmente, a pesar de que no se indica en la consigna, decidimos hacer una medición final con el planificador MLFQ que incluye la implementación de los puntos estrellas indicados anteriormente, para poder ver como varía su desempeño en comparación al MLFQ básico y al planificador *round-robin*. Similarmente al caso anterior, se puede referir a la [tabla](#mediciones-rr) para ver la definición de cada caso.

* *Quantum* normal:

![quantum-normal-mlfq-estrella](/imagenes/mlfq_estrella_normal.jpg "MLFQ estrella quantum normal")

* *Quantum* 10 veces menor:

![quantum-10-menor-mlfq-estrella](/imagenes/mlfq_estrella_10less.jpg "MLFQ estrella quantum 10 veces menor")

* *Quantum* 100 veces menor:

![quantum-100-menor-mlfq-estrella](/imagenes/mlfq_estrella_100less.jpg "MLFQ estrella quantum 100 veces menor")

Se puede observar que sucede lo mismo que con los planificadores anteriores, es decir que al disminuir el *quantum* las mediciones de `cpubench` son tan bajas que no se ven en el gráfico, sin embargo también se puede observar una considerable mejora en las mediciones de `iobench`, igualmente en las mediciones de `cpubench` que se pueden observar en el primer gráfico del *quantum* normal.

---

**[README](README.md) | [CONSIGNA](consigna.md) | [To Do](todo.md)**