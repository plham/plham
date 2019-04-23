/*
 *  This file is part of the X10 project (http://x10-lang.org).
 *
 *  This file is licensed to You under the Eclipse Public License (EPL);
 *  You may not use this file except in compliance with the License.
 *  You may obtain a copy of the License at
 *      http://www.opensource.org/licenses/eclipse-1.0.php
 *
 *  (C) Copyright IBM Corporation 2006-2015.
 */

package plham.util;
import x10.compiler.Inline;
import x10.util.*;

/** 
 * This generates a sequence of Randoms split from a given Random,
 * and only allows sequential access to its elements.
 */
public final class RandomSequenceBySplit implements Indexed[Random] {
    val rand:Random;
    var index:Long;
    var current:Random;

    public def this(rand0: Random) {
        this.rand = rand0;
	this.index = -1;
    }
    private def this(from:RandomSequenceBySplit) {
	this.rand = from.rand;
	this.index = from.index;
	this.current = from.current;
    }

    public @Inline operator this(i: Long): Random {
	assert i>= 0: "RandomSequenceBySplit: arguments " + i + " is negative.";
	assert i>= index: "RandomSequenceBySplit: this only allows sequential access. You are accessing element No. " + i + ", while this already accessing No. " + index;
	var r:Random = null;
	if(i==index) return current;
	//	if(i==index+1) { index++; return (current=rand.split());}
	while(i>index) {
	    this.index++;
	    r=rand.split();
	}
	return (current=r);
    }

    public def size() = index+10000;
    public def isEmpty() = false;
    public def contains(y:Random):Boolean {
	throw new UnsupportedOperationException();
    }
    public def containsAll(y:x10.util.Container[Random]):Boolean {
	throw new UnsupportedOperationException();
    }
    public def clone() {
	return new RandomSequenceBySplit(this);
    }

    private static class It implements ListIterator[Random] {
        
        private var i: Long;
        private val al: RandomSequenceBySplit;
        
        def this(al: RandomSequenceBySplit) {
	    this.al = al;
        }

        
        public def hasNext(): Boolean {
            return i+1 < al.size();
        }

        public def nextIndex(): Long {
            return ++i;
        }
        
        public def next(): Random {
            return al(++i);
        }

        public def hasPrevious(): Boolean {
            return i-1 >= 0;
        }

        public def previousIndex(): Long {
            return --i;
        }
        
        public def previous(): Random {
            return al(--i);
        }
        
        public def remove(): void {
	    throw new UnsupportedOperationException();
        }
        
        public def set(v: Random): void {
	    throw new UnsupportedOperationException();
        }
        
        public def add(v: Random): void {
	    throw new UnsupportedOperationException();
        }
    }
    public def iterator() = new It(this);


    public static def main(args:Rail[String]):void {
	val seed = 194327;
	val size = Long.parse(args(0));//*10000*10;
	val time = System.currentTimeMillis(); 
	val rgen = new Random(seed);
	val rgen2 = new Random(seed);
	val rx = new RandomSequenceBySplit(rgen2);
	var sum0:Long = 0L;
	var sum1:Long = 0L;
	
	for(i in 0..size) {
	    //	    val r = rgen.split();
	    //val r2 = rgen2(i);
	    val r2 = rx(i);
	    sum0+= r2.nextLong();
	    /*	    if(r.nextLong() != r2.nextLong()) {
		throw new Exception("Error at " + i);
		}*/
	}
	val diff = System.currentTimeMillis() -time; 
	Console.OUT.println("time:" + diff + ", for "+ size);

	val t2 = System.currentTimeMillis(); 
	for(i in 0..size) {
	    val r = rgen.split();
	    sum1+= r.nextLong();
	}
	val diff2 = System.currentTimeMillis() -t2; 
	Console.OUT.println("timeX:" + diff2+ ", for "+ size + ", diff" + (sum0-sum1));

    }
}
