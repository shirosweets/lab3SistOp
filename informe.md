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
    - [Respuesta 1a](#respuesta-1a)
  - [Pregunta 2](#pregunta-2)
    - [Respuesta 2a](#respuesta-2a)
    - [Respuesta 2b](#respuesta-2b)
- [Parte II: Cómo el planificador afecta a los procesos](#parte-ii-cómo-el-planificador-afecta-a-los-procesos)
- [Parte III: Rastreando la prioridad de los procesos](#parte-iii-rastreando-la-prioridad-de-los-procesos)
  - [MLFQ regla 3: rastreo de prioridad](#mlfq-regla-3-rastreo-de-prioridad)
- [Parte IV: Implementando MLFQ](#parte-iv-implementando-mlfq)
- [Puntos estrellas](#puntos-estrellas)

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
### Respuesta 1a
La política que utiliza el xv6 es **round robin**, esto le define un *quantum* (que en xv6 equivale a `10ms`) exacto a cada proceso, corriéndolos uno detrás de otro respecto a un orden que cuando se acaba la lista vuelve a empezar.

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

Dura 10 millones de ticks, que en xv6 asumimos que es en `10ms`.

En el archivo `lapic.c`:
```c
// The timer repeatedly counts down at bus frequency
// from lapic[TICR] and then issues an interrupt.
// If xv6 cared more about precise timekeeping,
// TICR would be calibrated using an external time source.
lapicw(TICR, 10000000);
```

### Respuesta 2b

# Parte II: Cómo el planificador afecta a los procesos

Pasamos a ver cómo el planificador de xv6 afecta a los distintos tipos de procesos en la práctica. Para ello se deberán integrar a xv6 los programas de espacio de usuario `iobench` y `cpubench` (que adjuntamos en el aula virtual). Estos programas realizan mediciones (no muy precisas) de respuesta de entrada/salida y de poder de cómputo, respectivamente.

> Importante: Aunque xv6 soporta múltiples procesadores, debemos ejecutar nuestras mediciones(`iobench` y `cpubench`) lanzando la máquina virtual con un único procesador. (i.e. `make CPUS=1 qemu-nox`).

1. Mida la respuesta de I/O y el poder de cómputo obtenido para las distintas combinaciones posibles entre 0 y 2 `iobench` junto con entre 0 y 2 `cpubench`, y grafique los resultados en el informe.

```java
Caso 0: 1 iobench
Caso 1: 1 iobench 1 cpubench
Caso 2: 1 iobench 2 cpubench
Caso 3: 1 cpubench
Caso 4: 1 cpubench 2 iobench
Caso 5: 2 cpubench 2 iobench
Caso 6: 2 cpubench
Caso 7: 2 iobench
```

2. Repita el experimento para quantums 10, 100 y 1000 veces más cortos. Tenga en cuenta que modificar el tick afecta el funcionamiento de `iobench` y `cpubench`, o sea que quizás necesite modificarlos para que mantengan un funcionamiento similar para que se puedan comparar los resultados en los distintos escenarios de prueba.

```java
Escenario 0: quantum por defecto, se corren los casos anteriores (caso 0 al 7, no lo tienen que repetir usen los resultados del apartado anterior)
Escenario 1: quantum 10 veces más corto, se corren los casos anteriores (caso 0 al 7)
Escenario 2: quantum 100 veces más corto, se corren los casos anteriores (caso 0 al 7)
Escenario 3: quantum 1000 veces más corto, se corren los casos anteriores (caso 0 al 7)
```

# Parte III: Rastreando la prioridad de los procesos

Habiendo visto las propiedades del planificador existente, lo reemplazar con un planificador MLFQ de tres niveles. A esto se debe hacer de manera gradual, primero rastrear la prioridad de los procesos, sin que esto afecte la planificación.

1. Agregue un campo en `struct proc` que guarde la prioridad del proceso (entre 0 y NPRIO-1 para #define NPRIO 3 niveles en total) y manténgala actualizada según el comportamiento del proceso:

- MLFQ regla 3: Cuando un proceso se inicia, su prioridad será máxima.
- MLFQ regla 4:
  - Descender de prioridad cada vez que el proceso pasa todo un *quantum* realizando cómputo.
  - Ascender de prioridad cada vez que el proceso bloquea antes de terminar su *quantum*.

> Nota: Este comportamiento es distinto al del MLFQ del libro.

1. Para comprobar que estos cambios se hicieron correctamente, modifique la función `procdump` (que se invoca con `CTRL-P`) para que imprima la prioridad de los procesos. Así, al correr nuevamente `iobench` y `cpubench`, debería darse que `cpubench` tenga baja prioridad mientras que `iobench` tenga alta prioridad.

## MLFQ regla 3: rastreo de prioridad

- El valor **máximo de la prioridad** es el valor `0`,
- y el valor `NPRIO` es la **prioridad mínima**.

Explicación de los archivos:

- `trap.h`: define los "traps" y los *interrupts del kernel*.

Entre ellos está el siguiente:

```c
#define IRQ_TIMER        0
```

Este define el interrupt llamado periodicamente por el hardware que usa el scheduler para medir los *quantums*.

- `trap.c`: este implementa todas las traps, entre ellas las **syscalls** (con la función de su mismo nombre, `syscall()`) y los **interrupts del timer** (con la función `yield()`).

Donde el descenso de prioridad ocurre en el `yield()`
```c
// Force process to give up CPU on clock tick.
// If interrupts were on while locks held, would need to check nlock.
if(myproc() && myproc()->state == RUNNING &&
    tf->trapno == T_IRQ0+IRQ_TIMER)
  yield();
```

Y los ascensos de prioridad ocurren en el `syscall()`

# Parte IV: Implementando MLFQ

Finalmente implementar la planificación propiamente dicha para que nuestro xv6 utilice MLFQ.
1. Modifique el planificador de manera que seleccione el próximo proceso a planificar siguiendo las siguientes reglas:
- MLFQ regla 1: Si el proceso A tiene mayor prioridad que el proceso B, corre A. (y no B)
- MLFQ regla 2: Si dos procesos A y B tienen la misma prioridad, corren en round-robin por el quantum determinado.

2. Repita las mediciones de la segunda parte para ver las propiedades del nuevo planificador.

3. Para análisis responda: ¿Se puede producir `starvation` en el nuevo planificador? Justifique su respuesta.

> Importante: Mucho cuidado con el uso correcto del mutex `ptable.lock`.

# Puntos estrellas

- Del planificador:
  1. [ ] Reemplace la política de ascenso de prioridad por la regla 5 de MLFQ de OSTEP: **Priority boost**.
  2. [ ] Modifique el planificador de manera que los distintos niveles de prioridad tengan distintas longitudes de quantum.
  3. [ ] Cuando no hay procesos para ejecutar, el planificador consume procesador de manera innecesaria haciendo busy waiting. Modifique el planificador de manera que ponga a dormir el procesador cuando no hay procesos para planificar, utilizando la instrucción hlt.
  4. [ ] (Difícil) Cuando xv6 corre en una máquina virtual con 2 procesadores, la performance de los procesos varía significativamente según cuántos procesos haya corriendo simultáneamente. ¿Se sigue dando este fenómeno si el planificador tiene en cuenta la localidad de los procesos e intenta mantenerlos en el mismo procesador?
  5. [ ] (Muy difícil) Y si no quisiéramos usar los *ticks periódicos del timer* por el problema de (1), ¿qué haríamos? Investigue cómo funciona e implemente un **tickless kernel**.

- De las herramientas de medición:
  - [ ] Llevar cuenta de cuánto tiempo de procesador se le ha asignado a cada proceso, con una system call para leer esta información desde espacio de usuario.

---

**[README](README.md) | [CONSIGNA](consigna.md) | [To Do](todo.md)*