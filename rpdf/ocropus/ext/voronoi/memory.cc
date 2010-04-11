/*
  $Date: 1999/10/15 12:40:27 $
  $Revision: 1.1.1.1 $
  $Author: kise $
  memory.c
*/

#include <stdio.h>
#include <stdlib.h>
#include "const.h"
#include "defs.h"
#include "extern.h"
#include "function.h"

namespace voronoi{
    unsigned int total_alloc = 0;

    void freeinit(struct Freelist *fl, int size)
    {
        fl -> head = (struct Freenode *) NULL;
        fl -> nodesize = size;
    }

    char *getfree(struct Freelist *fl)
    {
        int i; struct Freenode *t;
        if(fl->head == (struct Freenode *) NULL) {
            t =  (struct Freenode *) myalloc(sqrt_nsites * fl->nodesize);
            for(i=0; i<sqrt_nsites; i+=1) 	
                makefree((struct Freenode *)((char *)t+i*fl->nodesize), fl);
        }
        t = fl -> head;
        fl -> head = (fl -> head) -> nextfree;
        return((char *)t);
    }

    void makefree(struct Freenode *curr, struct Freelist *fl)
    {
        curr -> nextfree = fl -> head;
        fl -> head = curr;
    }

    char *myalloc(unsigned n)
    {
        char *t;
        if ((t= (char *) malloc((size_t) n)) == (char *) '0') {
            fprintf(stderr,
                    "Insufficient memory (%d bytes in use)\n",
                    total_alloc);
            exit(0);
        }
        total_alloc += n;
        return(t);
    }

    char *myrealloc(void *ptr, unsigned current, unsigned inc, size_t unit)
    {
        char *t;
        if ((t= (char *) realloc(ptr,(current+inc)*unit)) == (char *) '0') {
            fprintf(stderr,
                    "Insufficient memory (%d bytes in use)\n",
                    total_alloc);
            exit(0);
        }
        total_alloc += inc;
        return(t);
    }
}
