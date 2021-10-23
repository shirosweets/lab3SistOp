# Informe lab 3

- Fuentes, Tiffany
- Renison, Iván
- Vispo, Valentina Solange

---

**[README](README.md) | [CONSIGNA](consigna.md) | [To Do](todo.md)**

---

# Contenido

- [Informe lab 3](#informe-lab-3)
- [Contenido](#contenido)
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
- [Parte III: Rastreando la prioridad de los procesos](#parte-iii-rastreando-la-prioridad-de-los-procesos)
  - [MLFQ regla 3: rastreo de prioridad y asignación máxima](#mlfq-regla-3-rastreo-de-prioridad-y-asignación-máxima)
  - [MLFQ regla 4: descenso y ascenso de prioridad](#mlfq-regla-4-descenso-y-ascenso-de-prioridad)
- [Parte IV: Implementando MLFQ](#parte-iv-implementando-mlfq)
  - [MLFQ regla 1: correr el proceso de mayor prioridad](#mlfq-regla-1-correr-el-proceso-de-mayor-prioridad)
  - [MLFQ regla 2: round-robin para procesos de misma prioridad](#mlfq-regla-2-round-robin-para-procesos-de-misma-prioridad)
- [Puntos estrellas](#puntos-estrellas)
  - [Quantum distinto por prioridad](#quantum-distinto-por-prioridad)
  - [Priority Boost de OSTEP](#priority-boost-de-ostep)

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

- Para listar los procesos dentro de xv6 hacer `<CRTL-p>`.

- Salir de QEMU: `<CTRL-a> x`.

- Para iniciar QEMU CON pantalla VGA: `make qemu`.

- Para iniciar QEMU SIN pantalla VGA: `make qemu-nox`.

---

# Parte I: Estudiando el planificador de xv6

## Pregunta 1

1. Analizar el código del planificador y responda:
   a. ¿Qué política utiliza xv6 para elegir el próximo proceso a correr?

> Pista: xv6 nunca sale de la función scheduler por medios "normales".

### Respuesta 1

La política que utiliza el xv6 es **round robin**, que permite que los procesos corran consecutivamente durante un tiempo determinado denominado **quantum**.

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

2. Analizar el código que interrumpe a un proceso al final de su quantum y responda:
   
   a. ¿Cuánto dura un quantum en xv6?
   
   b. ¿Hay alguna forma de que a un proceso se le asigne menos tiempo?

> Pista: Se puede empezar a buscar desde la system call uptime .

### Respuesta 2a

Cada vez que hay un timer interrupt, el proceso que está corriendo le entrega el control al kernel, lo que quiere decir que el quantum dura el mismo tiempo que existe entre timer interrupts. En el archivo `lapic.c` se indica que el timer cuenta `10000000` ticks para hacer un timer interrupt, estos ticks dependen de la velocidad del procesador.

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

Con el código que tiene xv6 no es posible, ya que se le asigna el mismo quantum a todos los procesos, pero si es posible modificar el código para darle distintos quantums a los procesos.

# Parte II: Cómo el planificador afecta a los procesos

    El tipo de planificador puede influir en cuantos recursos se le asignan a cada proceso. En particular, el planificador *round robin* que viene en xv6 ejecuta a todos los procesos la misma cantidad de tiempo, mientras que el planificador MLFQ (multi level feedback queue) ejecuta mas a algunos procesos que a otros.

    Es interesante y muy útil, saber como afecta de distinta manera a los procesos de distintos tipos. Para eso, junto con la consigna nos dieron 2 programas para medir cuanto podian hacer de distintas cosas.

    El programa `cpubench` media la cantidad de operaciones de punto flotante que podía hacer en una cierta cantidad de ticks del sistema operativo. En particular, las operaciones en `MINTICKS` (definido por defecto en `250`) ticks del sistema operativo, y lo imprimía en KFLOPT (kilo floating point operations per tick) (por defecto ponía como unidad MFLOPT (mega en lugar de kilo), pero es un error, ya que lo calculaba en kilo).

    Los ticks del sistema operativos se obtienen con la llamada al sistema `uptime` y son la cantidad de interrupciones por timer producidos desde el inicio del sistema. Esto causa que si se hace que el timer sea mas chico, las mediciones de `cpubench` den menos, porque obviamente en menos tiempo se hacen menos cosas, pero, tiene la ventaja de que no depende de la velocidad del procesador, ya que por mas que cambie la velocidad a la que el procesador ejecuta las instrucciones, la cantidad de instrucciones ejecutadas entre una interrupción y la otra son las mismas.

    El otro programa que dieron es `iobench` que media la cantidad de escrituras y lecturas de un archivo que podía en `MINTICKS` ticks del sistema operativo, y las imprimía en IOP`MINTICKS`T (input output operations per `MINTICKS` ticks).

    Nosotros decidimos modificar un poco estos programas, para hacer que en lugar de imprimir la cantidad de operaciones por cierta cantidad de ticks, imprima la cantidad de operaciones y la cantidad de ticks por separado, para hacer nosotros la división, y evitar la perdida de error por el redondeo de la división entera (en `iobench` habían hecho que se imprima en `MINTICKS` ticks posiblemente para evitar un poco eso, pero nos pareció mejor directamente imprimir todo).

## Automatizado de testeos

    En la consigna se pide ejecutar en distintas combinaciones estos programas con el planificador por defecto y con el nuestro, para poder compararlos. Hacer eso a mano es bastante trabajo, así que nosotros decidimos intentar automatizarlo un poco.

    Para automatizarlo hicimos 2 scripts en la carpeta `Automatizar_mediciones`, uno que se encarga de ejecutar todos los test y guardar los resultados en archivos dentro de xv6, y otro que se encargue de extraer de xv6 los archivos esos.

    A continuación una explicación de como funciona cada uno de ellos:

### `AutoMed.sh`

    Este es el script que se encarga de ejecutar los test, redirigiendo las salidas a archivos dentro de xv6.

    Lo que hace es tener una lista de los comandos a ejecutar en cada test y para cada uno ejecuta xv6 durante un cierto tiempo pasandole a la entrada estándar el comando de este test.

### `Extraer_archivos.sh`

    Este es el script que se encarga de extraer los archivos de xv6.

    Lo que hace es tener una lista de los archivos que tiene que extraer, y para cada uno ejecuta qemu pasandole a la entrada estándar `cat nombre_del_archivo`, y redirigiendo la salida a un archivo del mismo nombre en linux, quitandole las primeras 14 lineas, que son los que se imprime hasta el `cat`, y los últimos 2 caracteres que son el `$ ` que se imprime después.


    Para generar los comandos que hay que ejecutar y los nombres de los archivos que hay que extraer usamos un pequeño archivo de haskell `Generador_listas.hs`, en donde `comandos_test` son los comandos y `archivos_test` los archivos.

    Para usar los scripts hay que desde la carpeta `xv6-modularized`, después de haber hecho un `make qemu` para que se compile xv6, hacer `bash ../Automatizar_mediciones/AutoMed.sh` para correr los test y después `bash ../Automatizar_mediciones/Extrear_archivos.sh` para extraer los archivos.

# Parte III: Rastreando la prioridad de los procesos

Habiendo visto las propiedades del planificador existente, reemplazarlo con un planificador MLFQ de tres niveles. Esto se debe hacer de manera gradual, primero rastrear la prioridad de los procesos, sin que esto afecte la planificación.

1. Agregue un campo en `struct proc` que guarde la prioridad del proceso (entre 0 y NPRIO-1 para #define NPRIO 3 niveles en total) y manténgala actualizada según el comportamiento del proceso:
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

Finalmente implementar la planificación propiamente dicha para que nuestro xv6 utilice MLFQ.

1. Modifique el planificador de manera que seleccione el próximo proceso a planificar siguiendo las siguientes reglas:
   
   * MLFQ regla 1: Si el proceso `A` tiene mayor prioridad que el proceso `B`, corre `A`. (y no `B`)
   * MLFQ regla 2: Si dos procesos `A` y `B` tienen la misma prioridad, corren en round-robin por el quantum determinado.

2. Repita las mediciones de la segunda parte para ver las propiedades del nuevo planificador.

3. Para análisis responda: ¿Se puede producir `starvation` en el nuevo planificador? Justifique su respuesta.

> Importante: Mucho cuidado con el uso correcto del mutex `ptable.lock`.

## MLFQ regla 1: correr el proceso de mayor prioridad

Para poder facilitar el manejo de las prioridades dicidimos usar colas, para hacer esto cambiamos el `struct ptable` del archivo `proc.c` que tiene la estructura de la tabla de procesos, para que contenga dos arreglos de punteros a procesos, `queue_first` que contiene los primeros procesos en la cola de cada prioridad, y `queue_last` que contiene los últimos procesos de la cola. También modificamos el `struct proc` que contiene la estructura de los procesos para añadir un puntero `next_proc` el cual va a apuntar al siguiente proceso en la cola.

Al inicializarse xv6 la memoria se inicializa en 0, por lo que las colas se inicializan en 0, luego al inicializarse un proceso en `userinit` se le asigna la prioridad más alta y se encola. En el scheduler se realiza un ciclo para encontrar el proceso de la prioridad más alta revisando el primer proceso de la cola de cada prioridad, dado que las colas solo tienen procesos que están en estado `RUNNABLE`, con ver si el primer elemento de la cola existe es suficiente para saber si hay procesos de dicha prioridad por correr. El ciclo comienza revisando la cola de prioridad mas baja (prioridad 0), por lo que siempre se va a correr el proceso de mayor prioridad.

Para asegurarnos de que en las colas solo haya procesos en estado `RUNNABLE` luego de correr cada proceso se saca de su cola, de esta forma si el proceso pasa a cualquier otro estado sólo se vuelve a encolar cuando pasa nuevamente a estado `RUNNABLE`, como por ejemplo en `wakeup` donde el proceso pasa de estado `SLEEP` a `RUNNABLE`.

Lo más importante de la implementación con colas es que mejora ligeramente el rendimiento, ya que a diferencia del scheduler original de xv6 no hay que recorrer la tabla completa de procesos para encontrar uno para ejecutar.

## MLFQ regla 2: round-robin para procesos de misma prioridad

Con la implementación que tenemos siempre se va a correr el proceso de prioridad más alta que este en estado `RUNNABLE`, luego de ejecutarse este proceso se van a revisar las colas nuevamente para buscar otro proceso por correr, en caso de que no haya un proceso de prioridad más alta que el que se ejecutó anteriormente, se seguiran ejecutando los procesos de la misma cola de prioridad de el proceso anterior, de esta forma los procesos de la misma prioridad se corren en round-robin por el quantum establecido.

Es importante observar que en esta implementación siempre que un proceso consuma su quantum y ejecute `yield()` para ceder el CPU, se baja la prioridad del proceso.

### Respuesta 3

Sí, se puede producir `starvation` en el nuevo planificador porque si hay un proceso largo `IO bound` o si hay varios procesos IO bound, con la política de ascensión que se implementó cada vez que se bloquea un proceso se le sube la prioridad, es decir que un proceso que devuelva el control al kernel antes de que termine el quantum ya que se bloquea siempre se va a mantener en la prioridad más alta, por lo que los procesos que esten en la prioridad más baja nunca tienen oportunidad de correr.

# Puntos estrellas

- Del planificador:
  
  1. [x] Reemplace la política de ascenso de prioridad por la regla 5 de MLFQ de OSTEP: **Priority boost**.
  2. [x] Modifique el planificador de manera que los distintos niveles de prioridad tengan distintas longitudes de quantum.
  3. [ ] Cuando no hay procesos para ejecutar, el planificador consume procesador de manera innecesaria haciendo `busy waiting`. Modifique el planificador de manera que ponga a dormir el procesador cuando no hay procesos para planificar, utilizando la instrucción `hlt`.
  4. [ ] (Difícil) Cuando xv6 corre en una máquina virtual con **2 procesadores**, la performance de los procesos varía significativamente según cuántos procesos haya corriendo simultáneamente. ¿Se sigue dando este fenómeno si el planificador tiene en cuenta la localidad de los procesos e intenta mantenerlos en el mismo procesador?
  5. [ ] (Muy difícil) Y si no quisiéramos usar los *ticks periódicos del timer* por el problema de *(1)*, ¿qué haríamos? Investigue cómo funciona e implemente un **tickless kernel**.

- De las herramientas de medición:
  
  - [ ] Llevar cuenta de cuánto tiempo de procesador se le ha asignado a cada proceso, con una system call para leer esta información desde espacio de usuario.

## Quantum distinto por prioridad

----

## Priority Boost de OSTEP

---

En este punto se cambio la implementación anterior del priority boost en el que se asciende la prioridad del proceso cada vez que este se bloquea, a una implementación mas parecida a la del libro OSTEP en la que se asciende la prioridad de todos los procesos a la prioridad más alta cada cierta cantidad de tiempo.

Para hacer esto creamos una función `priority_boost` en el archivo `proc.c` en el cual se recorren todos los procesos en la tabla de procesos y se coloca la prioridad de cada uno en 0 (que es la prioridad más alta). Decidimos definir una constante `BOOSTTIMER` que se encuentra definida en el archivo `param.h` para establecer la cantidad de tiempo que tiene que pasar entre cada priority boost.

Cada vez que se realiza un timer interrupt en xv6 se aumenta el contador de ticks que son los que llevan la cuenta del tiempo que ha pasado, por eso decidimos que en el archivo `trap.c`, en donde se aumenta la variable ticks , se chequee si ya paso la cantidad de tiempo definido por la constante `BOOSTTIMER`, de esta forma si `ticks % BOOSTTIMER == 0` se hace la llamada a `priority_boost` para ascender la prioridad de los procesos.

Debido a la implementación con colas que manejamos luego de ascender la prioridad de los procesos es importante actualizar el primer y último elemento de cada cola de prioridad, en este caso lo que hacemos es concatenar los procesos de manera que el último proceso de cada cola apunte al primer elemento de la siguiente cola no vacía.

---

**[README](README.md) | [CONSIGNA](consigna.md) | [To Do](todo.md)**