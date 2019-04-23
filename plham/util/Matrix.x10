package plham.util;
import x10.util.Random;
import x10.lang.Math;
import x10.util.ArrayList;

public class Matrix{
	public static val epsilon:Double = 1e-6; //行列式の絶対値がこの値以下ならゼロとみなす。
	public static val epsilon2:Double = 1e-6;
	public static val epsilon3:Double = 1e-2;
	public static val maxPositionSize:Long = Math.pow2(50); //Math.pow2(20);
	public static val index:Long = 31;
	public static val DEBUG:Long = 0;

	//有効制約法で非線形の目的関数を線形制約の元で最適化するベクトル値を返す.
	public static def ActiveSetMethod(A2:Rail[Rail[Double]],B2:Rail[Double],Q2:Rail[Rail[Double]],C2:Rail[Double],initialValue:Rail[Double]):Rail[Double]{

        //Console.OUT.println("# BENCHMARK: Matrix.ActiveSetMethod started at " + System.nanoTime());
		//Console.OUT.println("*initialValue");
		//dump(initialValue);
		var A:Rail[Rail[Double]] = Matrix.round(A2,index); //
		var B:Rail[Double] = Matrix.round(B2,index); //
		var Q:Rail[Rail[Double]] = Matrix.round(Q2,index); //
		var C:Rail[Double] = Matrix.round(C2,index); //
		assert Matrix.checkInitialASM(A,B,initialValue):"initialValueError";	//原点は各種制約条件すべて満たすはず.
		var out:Rail[Double] = initialValue;
		var lastOut:Rail[Double] = new Rail[Double](initialValue.size);
		var kenzan:Rail[Double];
		var s:Long =0;
		var activeCheck:Rail[boolean] = activeCheck(A,B,initialValue);
		var f:Long=0;
		var t:Long=-1;
		var repeat:boolean = true;
		var tout:Rail[Double] = new Rail[Double](out.size);
		//Console.OUT.println("gehu-1");
		tout = Matrix.luSolver(decompose(Q), C);
		do{
			//Console.OUT.println("gehu0");
			if(t==-1){
                setActiveCheck(activeCheck, A, B, out);
				//activeCheck = activeCheck2(A,B,out);
			}else{
				activeCheck(t) = false;
			}
			s=countActive(activeCheck);
			var smallA:Rail[Rail[Double] ] = getSmall(activeCheck,A);
			var smallB:Rail[Double] = getSmall(activeCheck,B);

			//Console.OUT.println("smallA");
			//dump(smallA);
			//Console.OUT.println("smallB");
			//dump(smallB);


			smallA = Matrix.round(smallA,index);
			smallB = Matrix.round(smallB,index);


			var mat:Rail[Rail[Double] ] = getMat(smallA,Q);
			var right:Rail[Double] = getRight(smallB,C);

			mat = Matrix.round(mat,index);
			right = Matrix.round(right,index);

			var ex:Rail[Rail[Double] ] = ExpansionCoefficientMatrix(mat,right);
			var echelon:Rail[Rail[Double] ] = echelonForm2(ex);
			var echelon2:Rail[Rail[Double] ] = echelonForm2(mat);


			ex = Matrix.round(ex,index);
			echelon = Matrix.round(echelon,index);			
			echelon2 = Matrix.round(echelon2,index);	

			
			var echelon4:Rail[Rail[Double] ];
			if(smallB.size!=0){
				var smallC:Rail[Rail[Double] ] = ExpansionCoefficientMatrix(smallA,smallB);
				smallC = Matrix.round(smallC,index);
				//Console.OUT.println("gehu1");
				echelon4 = echelonForm2(smallC);
				//Console.OUT.println("gehu2");
				echelon4 = Matrix.round(echelon4,index);
				//Console.OUT.println("gehu3");
			}else{
				echelon4 = new Rail[Rail[Double] ](initialValue.size+1); 
			}

			if (DEBUG == -2) {
				Console.OUT.println("============ASM"+f);
				Console.OUT.println("*A");
				dump(A);
				Console.OUT.println("*B");
				dump(B);
				Console.OUT.println("*Q");
				dump(Q);
				Console.OUT.println("*C");
				dump(C);
				Console.OUT.println("============");
				Console.OUT.println("*out");
				dump(out);
				Console.OUT.println("*check");
				dump(activeCheck);
				Console.OUT.println("*smallConstraits(s="+s);
				Console.OUT.println("**smallA");
				dump(smallA);
				Console.OUT.println("**smallB");
				dump(smallB);
				Console.OUT.println("*FOC of objective function");
				Console.OUT.println("**Q");
				dump(Q);
				Console.OUT.println("**C");
				dump(C);
				Console.OUT.println("============bigMat"+f);
				Console.OUT.println("*Mat(s="+s);
				dump(mat);
				Console.OUT.println("*right(s="+s);
				dump(right);
				Console.OUT.println("*ex"+s);
				dump(ex);
				Console.OUT.println("============echelon"+f);
				Console.OUT.println("*echelonex:"+s);
				dump(echelon);
				Console.OUT.println("*echelonMat:"+s);
				dump(echelon2);
			}

			lastOut = out;
			var hoge:Rail[Double];
			//matは実対照行列
			//解が一つの場合
			//if( Matrix.rank(echelon) == ex.size && Matrix.rank(echelon) == Matrix.rank(echelon2) ){
				//Console.OUT.println("*解は一つ("+ex.size+")");
			/*	if(Matrix.rank(echelon4) == initialValue.size ){
					hoge = new Rail[Double](initialValue.size);
					if(checkForIterative(smallA)){
						hoge = Matrix.iteration(smallA,smallB,10);
					}else{
						hoge = Matrix.luSolver(decompose(smallA),smallB);
					}
				}else*/ if(checkForIterative(mat)){
					hoge = new Rail[Double](ex.size);
					hoge = Matrix.iteration(mat,right,10);
				}else{
					hoge = new Rail[Double](ex.size);
					hoge = Matrix.luSolver(decompose(mat),right);
				}
				//Console.OUT.println("gehu0");
				hoge = round(hoge,index);

			//解が複数あるor制約条件により最適化不能な場合
			//}else{
			//	Console.OUT.println("*解はない");
			//	assert false:"matError";
			//}
			out = shorten(hoge,initialValue.size);
			var y1:Rail[Double] = new Rail[Double](initialValue.size);
			y1 = shorten2(hoge,initialValue.size);
			if (DEBUG == -2) {
				Console.OUT.println("*xy");
				dump(hoge);
				Console.OUT.println("*y");
				dump(y1);
				Console.OUT.println("*conditionCheck");
				dump(activeCheck);
			}

			kenzan = Matrix.multiply(mat,hoge);
			s = countActive(activeCheck);			
			if (DEBUG == -2) {
				Console.OUT.println("*newOut");
				dump(out);
				Console.OUT.println("*lastOut");
				dump(lastOut);
				Console.OUT.println("*kenzan");
				Console.OUT.println("**result");
				Matrix.dump(kenzan);
				Console.OUT.println("**right");
				dump(right);
				Console.OUT.println("*============step1end"+f);
				Console.OUT.println("*checkASM1");
			}



			if(!checkASM(out,lastOut,epsilon,epsilon2) ){
				//step2の作業

				var d:Rail[Double] = new Rail[Double](initialValue.size);
				var arufa:Rail[Double] = new Rail[Double](initialValue.size);
				var mvec:Rail[Double] = new Rail[Double](initialValue.size);
				for(i in 0..(d.size-1)){
					d(i) = out(i) - lastOut(i);
					mvec(i) =1.0;
				}

				if (DEBUG == -2) {
					Console.OUT.println("false");
					Console.OUT.println("*d");
					dump(d);
				}
				var min:Double = 1;
				for(i in 0..(A.size-1)){
					if( !activeCheck(i) ){
						if (DEBUG == -2) {
							Console.OUT.println("*bar("+i+")");
							Console.OUT.println("**b-ax");
							Console.OUT.println( (B(i) -  Matrix.multiply(A(i), lastOut)) );
							Console.OUT.println("**ad");
							Console.OUT.println(Matrix.multiply(A(i),d));
						}	
						if(Matrix.multiply(A(i),d) >0  ){
							var l:Double = ( B(i) -  Matrix.multiply(A(i), lastOut) )/ Matrix.multiply(A(i),d);
							if (DEBUG == -2) {
								Console.OUT.println("**l");
								Console.OUT.println(l);
							}
							if( l < min ){ min = l; }
						}						
					}
				}
				mvec = Matrix.multiply(min,mvec);
				if (DEBUG == -2) {
					Console.OUT.println("*mvec");
					dump(mvec);
				}
				for(i in 0..(d.size-1)){
					out(i) = lastOut(i) +mvec(i)*d(i);
				}
				out = round(out,index);
				if (DEBUG == -2) {
					Console.OUT.println("*nextOut");
					dump(out);
				}
				t=-1;
				repeat = true;
				if (DEBUG == -2) {
					Console.OUT.println("*============step2end"+f);
				}
			}else{
				//step3の作業
				if (DEBUG == -2) {
					Console.OUT.println("true");
					Console.OUT.println("*checkASM2");
				}
				if(hoge.size==initialValue.size){
					if (DEBUG == -2) {
						Console.OUT.println("true1");
					}
					repeat = false;
				}else if(hoge.size>initialValue.size  && checkPositive(y1) ){
					if (DEBUG == -2) {
						Console.OUT.println("true2");
					}
					repeat = false;
				}else{
					var oldT:Long = t;
					repeat = true;
					if(hoge.size - initialValue.size > 0){
						t=getNumMinMinusY(y1,activeCheck);
					}
					if (DEBUG == -2) {
						Console.OUT.println("false");
						Console.OUT.println("*t\n"+t);
					}
				}
				if (DEBUG == -2) {
					Console.OUT.println("*============step3end"+f);
				}
			}
			f++;
		//if(f>=20 && !checkASM(out,lastOut,epsilon,epsilon2) && checkASM(out,lastOut,epsilon3,epsilon3) ){ repeat = false; }
			if(f==1000){
				//assert false:"ASMError";
                //Console.OUT.println("# BENCHMARK: Matrix.ActiveSetMethod maybe fall into an infinite loop");
				for(i in 0..(out.size-1)){
					out(i) = Double.NaN;
					//out(i) = -1.0*(maxPositionSize as Double);
				}
				repeat = false;
			}
		}while(repeat);
        //Console.OUT.println("# BENCHMARK: Matrix.ActiveSetMethod finished at " + System.nanoTime());
		if (DEBUG == -2) {
			Console.OUT.println("**trueOPTIMAL");
			Matrix.dump(tout);
			Console.OUT.println("**continuousOPTIMAL");
			Matrix.dump(out);
			Console.OUT.println("**check");
			activeCheck = Matrix.activeCheck2(A,B,out);
			Console.OUT.println("**check");
			//dump(activeCheck);
		}
		return out;
	}


	//ASMのstep3での{t}のtを返す.
	public static def getNumMinMinusY(y1:Rail[Double],activeCheck:Rail[boolean]):Long{
		var out:Long = -1;
		var min:double = -1.0*epsilon;
		var count:Long =0;
		var y:Rail[Double] = new Rail[Double](activeCheck.size);
		for(i in 0..(activeCheck.size-1)){
			if(activeCheck(i)){
				y(i) = y1(count);
				count++;
			}else{
				y(i) = 0.0;
			}
		}
		for(i in 0..(activeCheck.size-1)){
			if(activeCheck(i) ){
				if(y(i) < min && y(i) < (-1.0*epsilon) ){
					min = y(i);
					out = i;
				}

			}
		}
		return out;
	}


	public static def simplex(obj:Rail[Double],C:double ,A:Rail[Rail[Double]],B:Rail[Double]):Rail[Double]{
		var n:Long = obj.size;
		var m:Long = A.size;

		var simptable:Rail[Rail[Double]] = new Rail[Rail[Double]](m+1);
		for(i in 0..m){
			simptable(i) = new Rail[Double](2*n+2*m+1);
		}

		for(i in 0..(m-1)){
			for(j in 0..(n-1)){
				simptable(i)(j) = A(i)(j);
				simptable(i)(n+j) = -1.0*A(i)(j);
			}
			for(var j:Long = 2*n; j<2*n+m; j++){
				if(i==j-2*n ){
					simptable(i)(j) = 1.0;
				}else{
					simptable(i)(j) = 0.0;
				}
			}
			for(var j:Long = 2*n+m; j<2*n+2*m; j++){
				if(i==j-2*n-m ){
					simptable(i)(j) = -1.0;
				}else{
					simptable(i)(j) = 0.0;
				}
			}
			simptable(i)(2*n+2*m) = B(i);

		}
			for(j in 0..(n-1)){
				simptable(m)(j) = obj(j);
				simptable(m)(n+j) = -1.0*obj(j);			
			}
			for(var j:Long = 2*n; j<2*n+2*m; j++){
				simptable(m)(j) = 0;
			}
			simptable(m)(2*n+2*m) = C;

		Console.OUT.println("*simpTable");
		dump(simptable);

		return simplex(simptable, n, m);

	}

	//A,Cの最終行が目的関数に対応.また，A,Cの最終列が右辺に対応.
	//元の正の変数の数をnとし，かつ，制約式の数をmとする．
	public static def simplex(C:Rail[Rail[Double]], n:Long, m:Long):Rail[Double]{
		assert C.size == m+1:"simplexError1";
		assert C(0).size == 2*n+2*m+1:"simplexError2";
		var count:Long = 0;
		var repeat:boolean = true;
		var A:Rail[Rail[Double]] = new Rail[Rail[Double]](m+1);
		for(i in 0..m){
			A(i) = new Rail[Double](2*n+2*m+1);
		}
		for(i in 0..(m-1)){
			for(j in 0..(2*m+2*n)){
				if(C(i)(2*m+2*n)>=0){
					A(i)(j) = C(i)(j);
				}else{
					A(i)(j) = -1.0*C(i)(j);
				}
			}
		}
			for(j in 0..(2*m+2*n)){
				A(m)(j) = C(m)(j);				
			}		


		Console.OUT.println("*simpTable");
		dump(A);

		do{
			Console.OUT.println("*============step"+count);
			var delta:Rail[Double] = new Rail[Double](2*n);
			var index:Rail[Long] = new Rail[Long](2*n); 
			for(k in 0..(2*n-1)){
				Console.OUT.println("**k="+k);
        			if ( A(m)(k) <  0) {
					var id:Long=-1;
					// (2) k列にある各行の要素で,各行の右端要素を
      					// 割ったものが最小となる行を探す
					var min:Double = Double.MAX_VALUE;
      					for(i in 0..(m-1)) {
						//Console.OUT.println("i="+i);
						var d:Double =0.0;
        					if ( A(i)(k) > 0.0 && A(i)(2*n+2*m) >=0.0 ){
       							d = A(i)(2*n+2*m)/A(i)(k);
							//Console.OUT.println("d="+d);
						}
        					if ( A(i)(k) >0 && d < min ) {
          						min = d;
          						id = i;
        					}
					}

					if(min!=Double.MAX_VALUE){
						delta(k) = min*A(m)(k);
						index(k) = id;
					}else{
						delta(k) = 0.0;
						index(k) = -1;
					}

				}else{
					delta(k) = 0.0;
					index(k) = -1;
				}
				Console.OUT.println("delta="+delta(k));
				Console.OUT.println("index="+index(k));
			}

			//上で調べた変数の中で、目的関数を一番多く変化させられる変数を選ぶ
			var selected:Long = -1;
			var minDelta:Double = 0.0;
			for(k in 0..(2*n-1)){
				if(delta(k) < minDelta){
					minDelta = delta(k);
					selected = k;
				}
			}

			Console.OUT.println("*minDelta="+minDelta);
			Console.OUT.println("*selected="+selected);
			if(selected==-1){ repeat = false; }else{	
				Console.OUT.print("*pivot("+selected+")("+index(selected)+")=");
				var pivot:Double = A(selected)(index(selected)); // ピボット要素
				Console.OUT.println(pivot);

     				//ピボット行の要素をピボット要素で割る
				for(j in 0..(2*n+2*m)) {
		        		A(selected)(j) = A(selected)(j)/pivot;
		      		}
				Console.OUT.println("*A:ピボット行の要素をピボット要素で割る");
				dump(A);

				// 掃き出し
				for(i in 0..m) {
 					if ( i != selected ) {
        	  				var d:Double = A(i)(index(selected));
        	  				for(j in 0..(2*n+2*m)) {
        	    					A(i)(j) = A(i)(j) - A(selected)(j)*d;
        	  				}
						Console.OUT.println("*A:"+i+"行目の吐き出し");
						dump(A);
        				}
      				}
				count++;
				if(count == 2){repeat = false;}
			}
		}while(repeat);

		Console.OUT.println("*lastA");
		dump(A);

		var out:Rail[Double] = new Rail[Double](n);
		for(i in 0..(m-1)){
			for(j in 0..(2*n-1)) {
				if(A(i)(j)==1.0){
					//Console.OUT.println("(i,j)=("+i+","+j+")");
					if(j<n){
						out(j)= A(i)(2*n+2*m);
					}else{
						out(j-n) = -1*A(i)(2*n+2*m);
					}				
				}
			}
		}
		Console.OUT.println("*out");
		dump(out);

		var obj:Rail[Double] = new Rail[Double](n);
		for(i in 0..(n-1)){
			obj(i) = C(m)(i);
		}

		var result:Double = multiply(obj,out) + C(m)(2*n+2*m);
		Console.OUT.println("*result:"+result);

		var out2:Rail[Double] =  new Rail[Double](m);
		for(i in 0..(m-1)){
			var x:Rail[Double] = new Rail[Double](n);
			for(j in 0..(n-1)){
				x(j)= C(i)(j);
			}
			out2(i) = C(i)(2*n+2*m) - multiply(shorten(C(i),n),out);
			//Console.OUT.println("*out2("+i+")="+out2(i));
		}
		Console.OUT.println("*distance");
		dump(out2); 


		return out;
	}


	//予算制約内で値が全て正の適当な内点を原点として返す.
	public static def initialASM0(A:Rail[Double],B:Double,r:Double):Rail[Double]{
		assert r>0.0 && r <1.0 : "initialRError";
		//Console.OUT.println("*initialZ:C");
		var out:Rail[Double] = new Rail[Double](A.size);
		var sum:double = 0.0;
		var C:Double = B*r;
		//Console.OUT.println("*initialZ:C"+B+":"+C);
		for(i in 0..(A.size-1) ){
			sum = sum + A(i);
		}
		for(i in 0..(A.size-1) ){
			out(i) = C/sum;
		}
		return out;
	}


	//制約条件を満たす実行可能解として原点を返す．
	public static def initialASM0(A:Rail[Rail[Double]],B:Rail[Double]):Rail[Double]{
		//Console.OUT.println("*initialValue");
		var out:Rail[Double] = new Rail[Double](A(0).size);
		//Matrix.dump(out);
		//var kenzan:Rail[Double];
		//Console.OUT.println("============initialKenzan");
		//kenzan = Matrix.multiply(A,out);
		//Console.OUT.println("*kenzan");
		//Console.OUT.println("**kenzan");
		//Matrix.dump(kenzan);
		//Console.OUT.println("**B");
		//dump(B);		
		assert checkInitialASM(A,B,out):"initialValueError";	//原点は各種制約条件すべて満たすはず.
		return out;
	}

	public static def checkPositive(x:Double):boolean{
		var s:Long = 0;
		if( round(x,index) >= epsilon2*Math.abs(round(x,index)) || round(x,index) >= epsilon ){
			return true;
		}else{
			return false;
		}
	}


	public static def checkPositive(x:Rail[Double]):boolean{
		var s:Long = 0;
		for(var i:Long = 0; i<x.size; i++){
			if( round(x(i),index) >= epsilon2*Math.abs(round(x(i),index)) || round(x(i),index) >= epsilon ){
				s++;
			}
		}
		if(x.size==s){
			return true;
		}else{
			return false;
		}
	}

	//「C*out <= D　が成り立つか」をcheckする.
	public static def checkInitialASM(C:Rail[Rail[Double]],D:Rail[Double], out:Rail[Double]):boolean{
		var output:boolean = true;
		var count:Long =0;
		var X:Rail[Double] = Matrix.multiply(C, out);
		//Console.OUT.println("**checkInitialASM");
		for(i in 0..(C.size-1)){
			if( round(round(D(i),index) - round(X(i),index),index) >= 0 || Math.abs( round(round(X(i),index)-round(D(i),index),index) ) <= Math.abs(round(X(i),index))*epsilon2 || Math.abs( round(round(X(i),index)-round(D(i),index),index) ) <= epsilon || Math.abs( round(round(X(i),index)-round(D(i),index),index) ) <= Math.abs(round(D(i),index))*epsilon2 ){
				count++;
 				//Console.OUT.print("true,");
			}else{
				//Console.OUT.print("false,");
			}
		}
		//Console.OUT.println("");
		if(count == C.size){
			//Console.OUT.println("true");
			output = true;
		}else{
			//Console.OUT.println("false");
			output = false;
		}
		return output;
	}


	//ASMでstep1での解と前回の値の差分がゼロとみなせるかcheckする.
	public static def checkASM(out:Rail[Double], lastOut:Rail[Double], epsilon:Double, epsilon2:Double):boolean{
		var count:Long =0;
		if (DEBUG == -2) {
			Console.OUT.println("**dif==0?:");
		}
		for(var i:Long = 0; i < out.size; ++i){
			if(Math.abs(round(round(out(i),index)-round(lastOut(i),index),index))<= epsilon2*Math.abs(round(lastOut(i),index)) || Math.abs(round(round(out(i),index)-round(lastOut(i),index),index))<= epsilon || Math.abs(round(round(out(i),index)-round(lastOut(i),index),index))<= epsilon2*Math.abs(round(out(i),index)) ){
				if (DEBUG == -2) {
					Console.OUT.print(i+",");
				}
				count++;
			}
		}
		if (DEBUG == -2) {
			Console.OUT.println("");
		}

		if(count == out.size){
			//Console.OUT.println("checkASM:true");
			return true;
		}else{
			//Console.OUT.println("checkASM:false");
			return false;
		}
	}


	public static def shorten(x:Rail[Double],s:Long):Rail[Double]{
		out:Rail[Double] = new Rail[Double](s);
		for(var i:Long=0; i<s; ++i){
			out(i) = x(i);
		}
		return out;
	}

	public static def shorten2(x:Rail[Double],s:Long):Rail[Double]{
		//Console.OUT.println("(xSize,s)=("+x.size+","+s+")");
		out:Rail[Double] = new Rail[Double]((x.size-s));
		for(var i:Long=s; i<x.size; ++i){
			//Console.OUT.println("i="+i);
			out(i-s) = x(i);
		}
		return out;
	}

	public static def getRight(smallB:Rail[Double],C:Rail[Double]):Rail[Double]{
		var n:Long = smallB.size + C.size;
		var out:Rail[Double] = new Rail[Double](n);
		for(var i:Long=0; i<n; ++i){
			if(i<C.size){
				out(i) = C(i);
			}else{
				out(i) = smallB(i-C.size);
			}
		}
		return out;
	}

	public static def getMat(smallA:Rail[Rail[Double]],Q:Rail[Rail[Double]]){
		var n:Long = Q.size + smallA.size;
		var out:Rail[Rail[Double] ] = new Rail[Rail[Double]](n);
		for(var i:Long=0; i<n; ++i){
			out(i) = new Rail[Double](n);
		}
		//Console.OUT.println("*Mat");
		//dump(out);
		for(var i:Long=0; i<n; ++i){
			for(var j:Long=0; j<n; ++j){
				if(i< Q.size && j<Q.size ){
					out(i)(j) = Q(i)(j);
				}else if(i >= Q.size && j<Q.size){
					out(i)(j) = smallA(i-Q.size)(j);
				}else if(i < Q.size && j >= Q.size){
					out(i)(j) = smallA(j-Q.size)(i);
				}else{
					out(i)(j) = 0.0;
				}
			}
		}
		return out;
	}

	public static def round(A:Rail[Rail[Double]],m:Long):Rail[Rail[Double]]{
		val n:Long = A.size;
		var out:Rail[Rail[Double]] = new Rail[Rail[Double]](n);
		for(var i:Long = 0; i<n; i++){
			out(i) = new Rail[Double](A(0).size);
		}
		for(var i:Long = 0; i<n; i++){
			for(var j:Long = 0; j<A(0).size; j++){
				out(i)(j) = Matrix.round(A(i)(j),m);
			}
		}
		return out;
	}

	public static def round(B:Rail[Double],m:Long):Rail[Double]{
		val n:Long = B.size;
		var out:Rail[Double] =new Rail[Double](n);
		for(var i:Long = 0; i<n; i++){
			out(i) = Matrix.round(B(i),m);
		}
		return out;
	}

	public static def round(x:Double,m:Long):Double{
		if(x==0.0){ return x; }
		var out:Double = 0.0;
		var ketasuu:Double = Math.ceil(Math.log10(Math.abs(x)));
		//Console.OUT.println("x:"+x);
		//Console.OUT.println("ketasuu:"+ketasuu);
		out = x*Math.pow(10,(-1*ketasuu));
		//Console.OUT.println("out0:"+out);
		out = out*Math.pow(10,m as Double);
		//Console.OUT.println("out1:"+out);
		out = Math.round(out);
		//Console.OUT.println("out2:"+out);
		out = out*Math.pow(10,(ketasuu -m) as Double);
		//Console.OUT.println("out3:"+out);
		return out;
	}


	public static def getSmall(activeCheck:Rail[boolean],B:Rail[Double]):Rail[Double] {
		var s:Long = countActive(activeCheck);
		var out:Rail[Double] = new Rail[Double](s);
		var j:Long =0;
		for(var i:Long = 0; i < activeCheck.size; ++i){
			if(activeCheck(i)){ 
				out(j) = B(i);
				j++;
			}
		}
		return out;
	}


	public static def getSmall(activeCheck:Rail[boolean],A:Rail[Rail[Double]]):Rail[Rail[Double] ] {
		var s:Long = countActive(activeCheck);
		var out:Rail[Rail[Double] ] = new Rail[Rail[Double]](s);
		var j:Long =0;
		for(var i:Long = 0; i < activeCheck.size; ++i){
			if(activeCheck(i)){ 
				out(j) = A(i);
				j++;
			}
		}
		return out;
	}


	public static def countActive(activeCheck:Rail[boolean]):Long{
		var count:Long = 0;
		for(var i:Long = 0; i < activeCheck.size; ++i){
			if(activeCheck(i)){ count++;	}
		}
		return count;
	}


	//C(i)*value = D(i) ⇒　out(i) = true
	public static def activeCheck(C:Rail[Rail[Double]],D:Rail[Double],value:Rail[Double]):Rail[boolean]{
		var out:Rail[boolean] = new Rail[boolean](C.size);
		for(var i:Long = 0; i < C.size; ++i){
			
			if( Math.abs( round(round(multiply(C(i), value),index) - round(D(i),index),index) ) <= epsilon2*Math.abs(round(D(i),index)) || Math.abs( round(round(multiply(C(i), value),index) - round(D(i),index),index) ) <= epsilon ||  Math.abs( round(round(multiply(C(i), value),index) - round(D(i),index),index) ) <= epsilon2*Math.abs( round( round( multiply(C(i), value),index ) - round(D(i),index),index ) ) ){
				out(i) =true;
			}else{ out(i) =false; }
		}
		return out;
	}

	public static def activeCheck2(C:Rail[Rail[Double]],D:Rail[Double],value:Rail[Double]):Rail[boolean]{
		var out:Rail[boolean] = new Rail[boolean](C.size);
		for(var i:Long = 0; i < C.size; ++i){
			if (DEBUG == -2) {
				//Console.OUT.println("***"+i+":");
				//Console.OUT.println("****C*out="+multiply(C(i), value) );
				//Console.OUT.println("****D="+D(i));
			}
			if( Math.abs(  round( round(multiply(C(i), value),index) - round(D(i),index),index) ) <= epsilon2*Math.abs(round(D(i),index) ) || Math.abs( round( round( multiply(C(i), value), index ) - round( D(i),index),index ) ) <= epsilon ||  Math.abs( round(  round(multiply(C(i), value),index) - round(D(i),index)  ,index) ) <= epsilon2*Math.abs( round(multiply(C(i), value),index))  ){
				out(i) =true;
			}else{ out(i) =false; }
			//if (DEBUG == -2) {
				//Console.OUT.println("****P="+out(i));
			//}
		}
		return out;
	}

    public static def setActiveCheck(activeCheck : Rail[Boolean], C : Rail[Rail[Double]], D : Rail[Double], value : Rail[Double]) {
        for (i in 0 .. (C.size - 1)) {
            // based on activeCheck2
			if( Math.abs(  round( round(multiply(C(i), value),index) - round(D(i),index),index) ) <= epsilon2*Math.abs(round(D(i),index) )
                || Math.abs( round( round( multiply(C(i), value), index ) - round( D(i),index),index ) ) <= epsilon
                ||  Math.abs( round(  round(multiply(C(i), value),index) - round(D(i),index)  ,index) ) <= epsilon2*Math.abs( round(multiply(C(i), value),index)) ) {
				activeCheck(i) = true;
            }
        }
    }

	//LU分解と反復法(反復回数はnum)により連立一次方程式の解を求める。 反復法の名前は不明(ニュメーリカルレシピに書かれていたやり方)
	public static def iteration(m:Rail[Rail[Double]], b:Rail[Double], num:Long):Rail[Double]{
		assert checkForIterative(m): "error";
		/*if( !checkForIterative(m)){
			Console.OUT.println("firstM="+m);
		}*/
		val n:Long = m.size;
		val lu:Rail[Rail[Double]] = decompose(m);
		var last:Rail[Double] = luSolver(lu,b);
		//var last:Rail[Double] = new Rail[Double](n); 	for(var i:Long = 0; i < n; ++i){	last(i) = b(i)/m(i)(i);	}
		var now:Rail[Double] = new Rail[Double](n);
		var d:Double = 0.0;
    		for(var i:Long = 0; i < num; ++i){
			d =0.0;
			var right:Rail[Double] = multiply(m,last);
		    	for(var j:Long = 0; j < right.size; ++j){ right(j) = right(j) -b(j);	}
			right = luSolver(lu,right);
		    	for(var j:Long = 0; j < right.size; ++j){
				d = d + right(j)*right(j);
				now(j) = last(j) -right(j);
			}
			d = Math.sqrt(d);
			//Console.OUT.println("*i="+i+": d = " + d);
			//dump(now);
			if(round(d,index) <epsilon2*round(d,index) || round(d,index) < epsilon ){  break; }
			last = now;
			now =  new Rail[Double](n);
		}

		/*if( !checkForIterative(m)){
			Console.OUT.println("last:");
			dump(last);
		}*/

		return last;
	}

	//ある正の値minを取ってきて,min>=1のときには1を返し，min<1のときには，min*10^x>=1となるような10^xを返す．
	public static def multiplier(min:Double){
		var out:Double =0.1;
		do{
			out =out*10;
		}while((out*min)<1);
		return out;
	}

	//行列×ベクトル
	public static def multiply(a:Rail[Rail[Double]], x:Rail[Double]):Rail[Double]{
		assert a(0).size == x.size: "errorMulti";
		val n:Long = a.size;
		val m:Long = a(0).size;
		//Console.OUT.println(n+","+m);
		var out:Rail[Double] = new Rail[Double](n);
    		for(var i:Long = 0; i < n; ++i){
    			for(var j:Long = 0; j < m; ++j){
				out(i) = out(i) + a(i)(j)*x(j);
			}
		}
		return out;

	}

	//内積(ベクトル×ベクトル)
	public static def multiply(a:Rail[Double], b:Rail[Double]):Double{
		assert a.size == b.size: "errorMulti";
		val n:Long = a.size;		
		var out:Double = 0.0;
		for(var i:Long=0; i<n; i++){
			out = out + a(i)*b(i);
		}
		return out;
	}

	//スカラー×ベクトル
	public static def multiply(a:Double, x:Rail[Double]):Rail[Double]{
		val n:Long = x.size;		
		var out:Rail[Double] = new Rail[Double](n);
    		for(var i:Long = 0; i < n; ++i){
			out(i) = a*x(i);
		}
		return out;
	}	

	//スカラー×行列
	public static def multiply(m:Double, A:Rail[Rail[Double]]):Rail[Rail[Double]]{
		val n:Long = A.size;
		var out:Rail[Rail[Double]] = new Rail[Rail[Double]](n);
		for(var i:Long = 0; i<n; i++){
			out(i) = new Rail[Double](A(0).size);
		}
		for(var i:Long = 0; i<n; i++){
			for(var j:Long = 0; j<A(0).size; j++){
				out(i)(j) = m*A(i)(j);
			}
		}
		return out;
	}

	public static def plus(x:Rail[Long], y:Rail[Long]):Rail[Long]{
		assert x.size == y.size : "plusError";
		val n = x.size;
		var out:Rail[Long] = new Rail[Long](n);
		for(i in 0..(n-1)){
			out(i) = x(i) +y(i);
		}
		return out;
	}

	//「引数の行列が対角優位か」をチェックする.
	//なお、「対角優位ならヤコビ反復法で収束する」は正しいが、対角優位でも収束することはいくらでもあるらしい。
	//詳細はhttp://www.math.ritsumei.ac.jp/yasutomi/jugyo/Numerical_Analysis/note5.pdf参照。
	public static def checkForIterative(m:Rail[Rail[Double]]):boolean{
		assert 	m.size == m(0).size: "error:" + m.size +","+m(0).size;
		val n:Long = m.size;
    		for(var i:Long = 0; i < n; ++i){
			val upper:Double = Math.abs(m(i)(i));
			var sum:Double =0;
    			for(var j:Long = 0; j < n; ++j){
				if(i!=j){
					sum= sum + Math.abs(m(i)(j));
				}
			}
			if(upper <= sum){ return false; }
		}
		return true;
	}


	//LU分解により連立一次方程式の解を求める。 
	public static def luSolver(lu:Rail[Rail[Double]], b:Rail[Double]):Rail[Double]{
		assert lu.size == lu(0).size: "error";
		assert lu.size == b.size: "error";
		val n:Long = lu.size;
		var x:Rail[Double] = new Rail[Double](n);

		// 前進代入(forward substitution)
    		//  LY=bからYを計算
    		for(var i:Long = 0; i < n; ++i){
        		var bly:Double = b(i);
        		for(var j:Long = 0; j < i; ++j){
            			bly = bly - lu(i)(j)*x(j);
        		}
        		x(i) = bly/lu(i)(i);
    		}
 
		// 後退代入(back substitution)
		//  UX=YからXを計算
		for(var i:Long = n-1; i >= 0; --i){
			var yux:Double = x(i);
			for(var j:Long = i+1; j < n; ++j){
				yux = yux - lu(i)(j)*x(j);
			}
			x(i) = yux;
		}

		return x;
	}

	//LU分解した行列の出力
	public static def decompose(m:Rail[Rail[Double]]):Rail[Rail[Double]] {
		if(m.size==m(0).size){
			assert Matrix.determinant(m) !=0.0: "The determinant is 0.";
		}
		val n:Long = m.size;
		var l:Double=0;

		//出力行列hの作成。初期値はmのディープコピー。		
		var h:Rail[Rail[Double]] = new Rail[Rail[Double]](n);
		for (i in 0..(n - 1)) {
			h(i) = new Rail[Double](n);
		}
		for (i in 0..(n - 1)) {
			for (j in 0..(n - 1)) {
				h(i)(j) = m(i)(j);
			}
		}

		//計算開始
		for(var i:Long = 0; i < n; ++i){
			// l_ijの計算(i >= j)
        		for(var j:Long = 0; j <= i; ++j){
            			l = h(i)(j);
            			for(var k:Long = 0; k < j; ++k){
                			l = l - h(i)(k)*h(k)(j);    // l_ik * u_kj
            			}
            			h(i)(j) = l;
        		}
 
		        // u_ijの計算(i < j)
		        for(var j:Long = i+1; j < n; ++j){
            			l = h(i)(j);
            			for(var k:Long = 0; k < i; ++k){
                			l = l- h(i)(k)*h(k)(j);    // l_ik * u_kj
            			}
            			h(i)(j) = l/h(i)(i);
        		}
    		}
		return h;
	}


	public static def pivoting(m:Rail[Rail[Double]], n:Long, k:Long){
    	// k行目以降でk列目の絶対値が最も大きい要素を持つ行を検索
		var p:Long = k; // 絶対値が最大の行
	    	var am:Double = Math.abs(m(k)(k));// 最大値
		//Console.OUT.println("**pivot"+k+","+n);
		//Console.OUT.println("**am("+k+")("+k+")="+am);
		for(var i:Long = k+1; i < n; i++){
        		if(Math.abs(m(i)(k)) > am){
        		    p = i;
        		    am = Math.abs(m(i)(k));
        		}
    		}
		//Console.OUT.println("**am("+p+")("+k+")="+am);
    		// k != pならば行を交換(ピボット選択)
    		if(k != p){ 
			for(var i:Long = 0; i <n; i++){
				var tmp:Double= m(k)(i);
				m(k)(i) = m(p)(i);
				m(p)(i) = tmp;
			}
		}
		//Console.OUT.println("*pivotM:");
		//dump(m);
	}

	//階段行列のrankの計算
	public static def rank(m:Rail[Rail[Double]]):Long{
		val n:Long = m.size;
		var out:Long = n;
		for (i in 0..(n - 1)) {
			var count:Long = 0;
			for (j in 0..(m(0).size-1)) {
				if(Math.abs( m(i)(j) )<= epsilon || Math.abs(  m(i)(j)  )<= epsilon2*Math.abs(  m(i)(j) ) /*|| m(i)(j).isNaN() || Math.abs(m(i)(j)).isInfinite()*/){ count++; }
			}
			if(count == m(0).size){ out--; }
		}
		return out;
	}


	public static def devideExpansionCoefficientMatrix1(a:Rail[Rail[Double]]):Rail[Rail[Double]]{
		var C:Rail[Rail[Double]] = new Rail[Rail[Double]](a.size);
		var D:Rail[Double] = new Rail[Double](a.size);
		for(i in 0..(a.size - 1)){
			C(i) = new Rail[Double](a(0).size-1);
		}

		for(i in 0..(a.size - 1)){
			for(j in 0..(a(0).size-2) ){
				C(i)(j) = a(i)(j);
			}
			D(i) = a(i)(a(0).size-1);
		}
		return C;
	}

	public static def devideExpansionCoefficientMatrix2(a:Rail[Rail[Double]]):Rail[Double]{
		var C:Rail[Rail[Double]] = new Rail[Rail[Double]](a.size);
		var D:Rail[Double] = new Rail[Double](a.size);
		for(i in 0..(a.size - 1)){
			C(i) = new Rail[Double](a(0).size-1);
		}

		for(i in 0..(a.size - 1)){
			for(j in 0..(a(0).size-2) ){
				C(i)(j) = a(i)(j);
			}
			D(i) = a(i)(a(0).size-1);
		}
		return D;
	}

	//拡大係数行列の作成
	public static def ExpansionCoefficientMatrix(a:Rail[Rail[Double]], b:Rail[Double]):Rail[Rail[Double]]{
		assert a.size == b.size: "errorEchelon1";
		//Console.OUT.println("**a.size:"+a.size);
		//Console.OUT.println("**a(0).size:"+a(0).size);
		//Console.OUT.println("**b.size:"+b.size);

		val n:Long = a.size;
		val nn:Long = a(0).size;
		var m:Rail[Rail[Double]] = new Rail[Rail[Double]](n);

		//拡大係数行列の形成
		for (i in 0..(n - 1)) {
			m(i) = new Rail[Double](nn+1);
		}
		for (i in 0..(n - 1)) {
			for (j in 0..(nn - 1)) {
				m(i)(j) = a(i)(j);
			}
			m(i)(nn) = b(i);
		}

		//Console.OUT.println("m:");
		//Matrix.dump(m);

		return m;
	}

	//行列の階段行列から0ベクトルの行を削除した行列を返す関数
	public static def echelonForm2(a:Rail[Rail[Double]]):Rail[Rail[Double]]{
		var m:Rail[Rail[Double]] = Matrix.echelonForm(a);
		var rank:Long = Matrix.rank(m);
		val n:Long = a.size;

		var out:Rail[Rail[Double]] = new Rail[Rail[Double]](rank);
		for (i in 0..(rank - 1)) {
			out(i) = new Rail[Double](n+1);
			out(i) = m(i);
		}
		return out;
	}

	//行列の階段行列の計算
	public static def echelonForm(a:Rail[Rail[Double]]):Rail[Rail[Double]]{
		//assert (a.size+1 == a(0).size)||(a.size == a(0).size) : "errorEchelon3";

		val n:Long = a.size;
		var m:Rail[Rail[Double]] = new Rail[Rail[Double]](n);


		for (i in 0..(n - 1)) {
			m(i) = new Rail[Double](a(0).size);
			for (j in 0..(a(0).size-1)) {
				m(i)(j) = a(i)(j);
			}
		}
		
		//Console.OUT.println("A:");
		//Matrix.dump(m);
		//Console.OUT.println("hogeeee");
		var pivot:Double;
		var mul:Double;
 
		// 対角成分が1で正規化された階段行列を作る(前進消去)
		for (i in 0..(n - 1)){
			//Console.OUT.println("hoge"+i);
			if(i<a(0).size){
				//ピボット選択
				Matrix.pivoting(m, n, i);
				//Console.OUT.println("M1("+n+","+i+"):");
				//Matrix.dump(m);
				// 対角成分の選択、この値で行成分を正規化
				pivot = m(i)(i);
				if(pivot>0){
					//Console.OUT.println("pivot("+i+")("+i+"):"+pivot);
					for (j in 0..(a(0).size-1)){
						//Console.OUT.println("ij:"+i+","+j);
				        	m(i)(j) = (1 / pivot) * m(i)(j);
						/*if(Math.abs(m(i)(j)) < epsilon || Math.abs(m(i)(j)) < epsilon2*Math.abs(m(i)(j)) ){
							m(i)(j)=0.0;
						}*/
				    	} 
					//Console.OUT.println("M2:");
					//Matrix.dump(m);

					/*for(var k:Long = 0; k < i; k++){
						for(var p:Long = i; p < a(0).size; p++){
							Console.OUT.println("kl:"+k+","+p);
							m(k)(p) =  m(k)(p) - m(k)(i)*m(i)(p);
						}
					}

					Console.OUT.println("M2.5:");
					Matrix.dump(m);*/

					// 階段行列を作る為に、現在の行より下の行について
				    	// i列目の成分が0になるような基本変形をする
				    	for (var k:Long = i + 1; k < n; k++){
				        	mul = m(k)(i);
		       				for (var l:Long = i; l < a(0).size; l++){
							//Console.OUT.println("kl:"+k+","+l);
							m(k)(l) =  m(k)(l) - mul*m(i)(l);
							/*if(Math.abs(m(k)(l)) < epsilon || Math.abs(m(k)(l)) < epsilon2*Math.abs(m(k)(l)) ){
								m(k)(l)=0.0;
							}*/
						}
					}
				}	
				//Console.OUT.println("M3:");
				//Matrix.dump(m);
			}
		}


		//Console.OUT.println("lastM:");
		//Matrix.dump(m);
		return m;
	}


	//行列式の計算
	public static def determinant(m:Rail[Rail[Double]] ):Double{
		var det:Double =1.0;
		assert 	m.size == m(0).size: "error";
		val n:Long = m.size;

		//mのディープコピーhの作成。
		var h:Rail[Rail[Double]] = new Rail[Rail[Double]](n);
		for (i in 0..(n - 1)) {
			h(i) = new Rail[Double](n);
		}

		for (i in 0..(n - 1)) {
			for (j in 0..(n - 1)) {
				h(i)(j) = m(i)(j);
			}
		}

		//Console.OUT.println("copyDETERM:");
		//Matrix.dump(h);

		//計算開始
		for(var i:Long =0; i < n; ++i){
			for(var j:Long =0; j < n; ++j){
  				if(i<j){
					var buf:Double = h(j)(i)/h(i)(i);
					for(var k:Long = 0; k<n; k++){
						h(j)(k) -= h(i)(k)*buf;
					}
				}
			}
		}

		//Console.OUT.println("copyDETERM:");
		//Matrix.dump(h);

		for(var i:Long =0; i < n; i++){
			det=det*h(i)(i);
		}
		return det;
	}


	//ベクトルの標準出力
	public static def dump(v:Rail[Double]):void{
		val n:Long = v.size;
		for(i in 0..(n - 1)){
			Console.OUT.print(v(i)+"\t");
		}
		Console.OUT.println("\n");
	}

	public static def dump(v:Rail[boolean]):void{
		val n:Long = v.size;
		for(i in 0..(n - 1)){
			Console.OUT.print(v(i)+"\t");
		}
		Console.OUT.println("\n");
	}

	public static def dump(v:Rail[Long]):void{
		val n:Long = v.size;
		for(i in 0..(n - 1)){
			Console.OUT.print(v(i)+"\t");
		}
		Console.OUT.println("\n");
	}

	//行列の標準出力
	public static def dump(m:Rail[Rail[Double]]):void{
		Console.OUT.print("\n");
		val n:Long = m.size;
		for(i in 0..(n - 1)){
			for(j in 0..(m(i).size - 1)){
				Console.OUT.print(m(i)(j)+"\t");
			}
			Console.OUT.println("");
		}
		Console.OUT.println("");
		//Console.OUT.println("M");
	}

	public static def minimum(base:ArrayList[Double]):Double{
		val n = base.size();
		var hoge:Rail[Double] = new Rail[Double](n);
		for(i in 0..(n - 1)){
			hoge(i) = base.get(i);
		}
		return Matrix.minimum(hoge);
	}

	public static def minimum(x:Rail[Double]):Double{
		var out:Double = maxPositionSize as Double;
		for(i in 0..(x.size - 1)){
			if(x(i)<out){
				out = x(i);
			}
		}
		return out;
	}


	public static def maximum(x:Rail[Double]):Double{
		var out:Double = -1*maxPositionSize as Double;
		for(i in 0..(x.size - 1)){
			if(x(i)>out){
				out = x(i);
			}
		}
		return out;
	}


	public static def main(args:Rail[String]) {


	// determinantメソッドのテスト(http://thira.plavox.info/blog/2008/06/_c.html)
	/*	val M = [
			[1.00,8.00,9.00],
			[-3.00,2.00,1.00],
			[4.00,1.00,5.00]
			];
		val n = M.size;
		val m = new Rail[Rail[Double]](n);
		for (i in 0..(n - 1)) {
			m(i) = new Rail[Double](M(i));
		}
		Matrix.dump(m);
		val det:Double = Matrix.determinant(m);
		Console.OUT.println("det="+det);
		val lu:Rail[Rail[Double]] = Matrix.decompose(m); */
	

	//LU分解のテスト(http://www.ced.is.utsunomiya-u.ac.jp/lecture/2012/prog/p2/kadai3/no3/lu.pdf)
	/*	val M = [
			[8.00,16.00,24.00,32.00],
			[2.00,7.00,12.00,17.00],
			[6.00,17.00,32.00,59.00],
			[7.00,22.00,46.00,105.00]
			];
		val n = M.size;
		val m = new Rail[Rail[Double]](n);
		for (i in 0..(n - 1)) {
			m(i) = new Rail[Double](M(i));
		}
		Matrix.dump(m);
		val det:Double = Matrix.determinant(m);
		Console.OUT.println("det="+det);
		Matrix.dump(m);
		val lu:Rail[Rail[Double]] = Matrix.decompose(m);
		Matrix.dump(lu);
		Matrix.dump(m);
	*/
	//LU分解により連立一次方程式の解を求めるテスト(http://www.osakac.ac.jp/labs/mandai/writings/sd1-fukp02-f.pdf)
	/*	val M = [
			[1.00,-1.00,0.00],
			[1.00,0.00,1.00],
			[3.00,1.00,1.00]
			];
		val B = [-5,-1,-2];
		val n = M.size;
		val m = new Rail[Rail[Double]](n);
		val b = new Rail[Double](n);
		for (i in 0..(n - 1)) {
			m(i) = new Rail[Double](M(i));
			b(i) = B(i);
		}

		Matrix.dump(m);
		Matrix.dump(b);

		val det:Double = Matrix.determinant(m);
		Console.OUT.println("det="+det);

		val sol = luSolver(decompose(m),b);
		Matrix.dump(sol);

		Matrix.dump(m);
		Matrix.dump(b);
	*/

	//行列が対角優位かを調べるメソッドのテスト1: falseの場合(http://next1.msi.sk.shibaura-it.ac.jp/MULTIMEDIA/numeanal1/node33.html) 

	/*	val M = [
			[6.00,4.00,-3.00],
			[4.00,-2.00,0.00],
			[-3.00,0.00,1.00]
			];
		val n = M.size;
		val m = new Rail[Rail[Double]](n);
		for (i in 0..(n - 1)) {
			m(i) = new Rail[Double](M(i));
		}

		Matrix.dump(m);

		Console.OUT.println("check="+Matrix.checkForIterative(m)); //falseを出す。｀
*/
	

	//行列が対角優位かを調べるメソッドのテスト2: truthの場合(http://next1.msi.sk.shibaura-it.ac.jp/MULTIMEDIA/numeanal1/node33.html) 
/*
		val M = [
			[7.00,2.00,0.00],
			[3.00,5.00,-1.00],
			[0.00,5.00,-6.00]
			];
		val n = M.size;
		val m = new Rail[Rail[Double]](n);
		for (i in 0..(n - 1)) {
			m(i) = new Rail[Double](M(i));
		}

		Matrix.dump(m);

		Console.OUT.println("check="+Matrix.checkForIterative(m)); //truthを出す。｀
*/
	//行列によるベクトルの変換を求めるメソッドのテスト（http://proofcafe.org/k27c8/math/math/liner_algebraI/page/transformation_of_vector_by_matrix/）
	/*	val A = [
			[1.00,3.00,2.00],
			[0.00,1.00,-1.00]
			];
		val X = [1.00,1.00,1.00];
		val m = A.size;
		val n = A(0).size;
		val a = new Rail[Rail[Double]](m);
		val x = new Rail[Double](n);
		for (i in 0..(m - 1)) {
			a(i) = new Rail[Double](A(i));
		}
		for (i in 0..(n - 1)) {
			x(i) = X(i);
		}
		Matrix.dump(a);
		Matrix.dump(x);
		val y = multiply(a,x);

		Matrix.dump(y);
	*/

	//反復法により連立一次方程式の解を求めるテスト(http://www.geocities.jp/supermisosan/jacobi.html)
/*		val M = [
			[3.00,-6.00,9.00],
			[2.00,5.00,-8.00],
			[1.00,-4.00,7.00]
			];
		val B = [6,8,2];
		val n = M.size;
		val m = new Rail[Rail[Double]](n);
		val b = new Rail[Double](n);
		for (i in 0..(n - 1)) {
			m(i) = new Rail[Double](M(i));
			b(i) = B(i);
		}

		Matrix.dump(m);
		Matrix.dump(b);

		val sol = iteration(m, b, 10);
		//Console.OUT.println("*sol");
		Matrix.dump(sol);

		Matrix.dump(m);
		Matrix.dump(b);*/

		//Console.OUT.println("hugee!");

	/*	val a = [
			[3.00,-6.00,9.00],
			[2.00,5.00,-8.00],
			[1.00,-4.00,7.00]
			];*/
/*
		val a = [[1.0,1.0,-3.0,-4.0],
                         [2.0,2.0,-6.0,-8.0],
                         [3.0,6.0,-2.0,1.0],
                         [2.0,2.0,2.0,-3.0]];

		//val b = [6,8,2];
		val b = [-1.0,-2.0,8.0,2.0];
		val v = [4,5,6,7];
		val n = a.size;
		Console.OUT.println("n="+n);
		val c = new Rail[Rail[Double]](n);
		val d = new Rail[Double](n);
		val w = new Rail[Double](n);
		for (i in 0..(n - 1)) {
			c(i) = new Rail[Double](a(i));
			d(i) = b(i);
			w(i) = v(i) as Double;
		}

		Console.OUT.println("A");
		Matrix.dump(c);
		Console.OUT.println("b");
		Matrix.dump(d);

		var m:Rail[Rail[Double]] = Matrix.echelonForm2(Matrix.ExpansionCoefficientMatrix(c,d));
		Console.OUT.println("m");
		Matrix.dump(m);
		var sol:Rail[Double] = Matrix.minDist(m,w);
		Console.OUT.println("sol");
		Matrix.dump( sol );
		val out:Rail[Double] = Matrix.multiply(c,sol);
		Console.OUT.println("kenzan");
		Matrix.dump(out);
		Matrix.dump(d);
	*/

	//有効制約法により二次計画問題を解くテスト1(http://suzuichibolgpg.blog.fc2.com/blog-entry-206.html ):OK 
	/*	
		var Q:Rail[Rail[Double]] = new Rail[Rail[Double]](2);
		Q(0) = new Rail[Double](2);
		Q(1) = new Rail[Double](2);		
		Q(0)(0) = 8.00;
		Q(0)(1) = 2.00;
		Q(1)(0) = 2.00;
		Q(1)(1) = 2.00;
		Console.OUT.println("============settings");
		Console.OUT.println("*FOC of objective function");
		Console.OUT.println("**Q");
		Matrix.dump(Q);

		val c = [-2.0,-3.0];

		var C:Rail[Double] = new Rail[Double](c.size);
		for(i in 0..(c.size-1)){
			C(i) =c(i);
		}
		Console.OUT.println("**C");
		Matrix.dump(C);

		var constraints:Rail[Rail[Double]] = new Rail[Rail[Double]](3);
		for (i in 0..(constraints.size-1)) {
			constraints(i) = new Rail[Double](3);
		}
		constraints(0)(0) = -1.00; constraints(0)(1) = 1.00; constraints(0)(2) = 0.00;
		constraints(1)(0) = 1.00; constraints(1)(1) = 1.00; constraints(1)(2) = 4.00;
		constraints(2)(0) = 1.00; constraints(2)(1) = 0.00; constraints(2)(2) = 3.00;

		var A:Rail[Rail[Double]] = Matrix.devideExpansionCoefficientMatrix1(constraints);
		var B:Rail[Double] = Matrix.devideExpansionCoefficientMatrix2(constraints);

		Console.OUT.println("*constraints");
		Console.OUT.println("**A");
		Matrix.dump(A);
		Console.OUT.println("**B");
		Matrix.dump(B);
		//原点を代入し，原点が制約条件を全て満たすことを確認.
		var initialValue:Rail[Double] =  Matrix.initialASM0(A,B);
		initialValue = Matrix.ActiveSetMethod(A,B,Q,C,initialValue);
		Console.OUT.println("*answer");	
		dump(initialValue );
	*/	

	//有効制約法により二次計画問題を解くテスト2(http://www.math.cm.is.nagoya-u.ac.jp/~kanamori/lecture/lec.2007.1st.suurijouhou1/12.2007.07.12.quad.pdf の演習問題1):OK
	/*		
		var Q:Rail[Rail[Double]] = new Rail[Rail[Double]](2);
		Q(0) = new Rail[Double](2);
		Q(1) = new Rail[Double](2);		
		Q(0)(0) = 2.00;
		Q(0)(1) = 0.00;
		Q(1)(0) = 0.00;
		Q(1)(1) = 2.00;
		Console.OUT.println("============settings");
		Console.OUT.println("*FOC of objective function");
		Console.OUT.println("**Q");
		Matrix.dump(Q);

		val c = [-2.0,-2.0];

		var C:Rail[Double] = new Rail[Double](c.size);
		for(i in 0..(c.size-1)){
			C(i) =c(i);
		}
		Console.OUT.println("**C");
		Matrix.dump(C);

		var constraints:Rail[Rail[Double]] = new Rail[Rail[Double]](2);
		for (i in 0..(constraints.size-1)) {
			constraints(i) = new Rail[Double](3);
		}
		constraints(0)(0) = -1.00; constraints(0)(1) = 0.00; constraints(0)(2) = 0.00;
		constraints(1)(0) = 0.00; constraints(1)(1) = -1.00; constraints(1)(2) = -1.00;

		var A:Rail[Rail[Double]] = Matrix.devideExpansionCoefficientMatrix1(constraints);
		var B:Rail[Double] = Matrix.devideExpansionCoefficientMatrix2(constraints);

		var initialValue:Rail[Double] =  new Rail[Double](2);
		initialValue(0) = 2.0;
		initialValue(1) = 2.0;

		Console.OUT.println("*constraints");
		Console.OUT.println("**A");
		Matrix.dump(A);
		Console.OUT.println("**B");
		Matrix.dump(B);
		initialValue = Matrix.ActiveSetMethod(A,B,Q,C,initialValue);
		Console.OUT.println("*answer");	
		dump(initialValue );	
	*/	
	//有効制約法により二次計画問題を解くテスト3(http://www.math.cm.is.nagoya-u.ac.jp/~kanamori/lecture/lec.2007.1st.suurijouhou1/12.2007.07.12.quad.pdf の演習問題2):OK
	/*	
		var Q:Rail[Rail[Double]] = new Rail[Rail[Double]](2);
		Q(0) = new Rail[Double](2);
		Q(1) = new Rail[Double](2);		
		Q(0)(0) = 2.00;
		Q(0)(1) = 0.00;
		Q(1)(0) = 0.00;
		Q(1)(1) = 2.00;
		Console.OUT.println("============settings");
		Console.OUT.println("*FOC of objective function");
		Console.OUT.println("**Q");
		Matrix.dump(Q);

		val c = [14.0,6.0];

		var C:Rail[Double] = new Rail[Double](c.size);
		for(i in 0..(c.size-1)){
			C(i) =c(i);
		}
		Console.OUT.println("**C");
		Matrix.dump(C);

		var constraints:Rail[Rail[Double]] = new Rail[Rail[Double]](2);
		for (i in 0..(constraints.size-1)) {
			constraints(i) = new Rail[Double](3);
		}
		constraints(0)(0) = 1.00; constraints(0)(1) = 1.00; constraints(0)(2) = 2.00;
		constraints(1)(0) = 1.00; constraints(1)(1) = 2.00; constraints(1)(2) = 3.00;

		var A:Rail[Rail[Double]] = Matrix.devideExpansionCoefficientMatrix1(constraints);
		var B:Rail[Double] = Matrix.devideExpansionCoefficientMatrix2(constraints);

		Console.OUT.println("*constraints");
		Console.OUT.println("**A");
		Matrix.dump(A);
		Console.OUT.println("**B");
		Matrix.dump(B);
		//原点を代入し，原点が制約条件を全て満たすことを確認.
		var initialValue:Rail[Double] =  Matrix.initialASM0(A,B);
		initialValue = Matrix.ActiveSetMethod(A,B,Q,C,initialValue);
		Console.OUT.println("*answer");	
		dump(initialValue );
	*/	

	//有効制約法により二次計画問題を解くテスト4(http://www.math.cm.is.nagoya-u.ac.jp/~kanamori/lecture/lec.2007.1st.suurijouhou1/12.2007.07.12.quad.pdf の演習問題3):OK
	/*	
		var Q:Rail[Rail[Double]] = new Rail[Rail[Double]](2);
		Q(0) = new Rail[Double](2);
		Q(1) = new Rail[Double](2);		
		Q(0)(0) = 2.00;		Q(0)(1) = 0.00;
		Q(1)(0) = 0.00;		Q(1)(1) = 2.00;
		Console.OUT.println("============settings");
		Console.OUT.println("*FOC of objective function");
		Console.OUT.println("**Q");
		Matrix.dump(Q);

		val c = [1.0,2.0];

		var C:Rail[Double] = new Rail[Double](c.size);
		for(i in 0..(c.size-1)){
			C(i) =c(i);
		}
		Console.OUT.println("**C");
		Matrix.dump(C);

		var constraints:Rail[Rail[Double]] = new Rail[Rail[Double]](3);
		for (i in 0..(constraints.size-1)) {
			constraints(i) = new Rail[Double](3);
		}
		constraints(0)(0) = -1.00; constraints(0)(1) = 0.00; constraints(0)(2) = 0.00;
		constraints(1)(0) = 0.00; constraints(1)(1) = -1.00; constraints(1)(2) = 0.00;
		constraints(2)(0) = 1.00; constraints(2)(1) = 1.00; constraints(2)(2) = 1.00;

		var A:Rail[Rail[Double]] = Matrix.devideExpansionCoefficientMatrix1(constraints);
		var B:Rail[Double] = Matrix.devideExpansionCoefficientMatrix2(constraints);

		Console.OUT.println("*constraints");
		Console.OUT.println("**A");
		Matrix.dump(A);
		Console.OUT.println("**B");
		Matrix.dump(B);
		//原点を代入し，原点が制約条件を全て満たすことを確認.
		var initialValue:Rail[Double] =  Matrix.initialASM0(A,B);
		initialValue = Matrix.ActiveSetMethod(A,B,Q,C,initialValue);
		Console.OUT.println("*answer");	
		dump(initialValue );
	*/	

	//有効制約法により二次計画問題を解くテスト5(http://www.math.cm.is.nagoya-u.ac.jp/~kanamori/lecture/lec.2007.1st.suurijouhou1/12.2007.07.12.quad.pdf の演習問題4):OK
	/*		
		var Q:Rail[Rail[Double]] = new Rail[Rail[Double]](2);
		Q(0) = new Rail[Double](2);
		Q(1) = new Rail[Double](2);		
		Q(0)(0) = 2.00;
		Q(0)(1) = -1.00;
		Q(1)(0) = -1.00;
		Q(1)(1) = 2.00;
		Console.OUT.println("============settings");
		Console.OUT.println("*FOC of objective function");
		Console.OUT.println("**Q");
		Matrix.dump(Q);

		val c = [3.0,0.0];

		var C:Rail[Double] = new Rail[Double](c.size);
		for(i in 0..(c.size-1)){
			C(i) =c(i);
		}
		Console.OUT.println("**C");
		Matrix.dump(C);

		var constraints:Rail[Rail[Double]] = new Rail[Rail[Double]](3);
		for (i in 0..(constraints.size-1)) {
			constraints(i) = new Rail[Double](3);
		}
		constraints(0)(0) = -1.00; constraints(0)(1) = 0.00; constraints(0)(2) = 0.00;
		constraints(1)(0) = 0.00; constraints(1)(1) = -1.00; constraints(1)(2) = 0.00;
		constraints(2)(0) = 1.00; constraints(2)(1) = 1.00; constraints(2)(2) = 2.00;

		var A:Rail[Rail[Double]] = Matrix.devideExpansionCoefficientMatrix1(constraints);
		var B:Rail[Double] = Matrix.devideExpansionCoefficientMatrix2(constraints);

		Console.OUT.println("*constraints");
		Console.OUT.println("**A");
		Matrix.dump(A);
		Console.OUT.println("**B");
		Matrix.dump(B);
		//原点を代入し，原点が制約条件を全て満たすことを確認.
		var initialValue:Rail[Double] =  Matrix.initialASM0(A,B);
		initialValue = Matrix.ActiveSetMethod(A,B,Q,C,initialValue);
		Console.OUT.println("*answer");	
		dump(initialValue );
	*/	
		
	//有効制約法により二次計画問題を解くテスト6(http://www.math.cm.is.nagoya-u.ac.jp/~kanamori/lecture/lec.2007.1st.suurijouhou1/12.2007.07.12.quad.pdf の復習2):OK
	/*	
		var Q:Rail[Rail[Double]] = new Rail[Rail[Double]](2);
		Q(0) = new Rail[Double](2);
		Q(1) = new Rail[Double](2);		
		Q(0)(0) = 2.00;		Q(0)(1) = 1.00;
		Q(1)(0) = 1.00;		Q(1)(1) = 2.00;
		Console.OUT.println("============settings");
		Console.OUT.println("*FOC of objective function");
		Console.OUT.println("**Q");
		Matrix.dump(Q);

		val c = [2.0,2.0];

		var C:Rail[Double] = new Rail[Double](c.size);
		for(i in 0..(c.size-1)){
			C(i) =c(i);
		}
		Console.OUT.println("**C");
		Matrix.dump(C);

		var constraints:Rail[Rail[Double]] = new Rail[Rail[Double]](4);
		for (i in 0..(constraints.size-1)) {
			constraints(i) = new Rail[Double](3);
		}
		constraints(0)(0) = 1.00; constraints(0)(1) = 0.00; constraints(0)(2) = 1.00;
		constraints(1)(0) = 0.00; constraints(1)(1) = 1.00; constraints(1)(2) = 1.00;
		constraints(2)(0) = -1.00; constraints(2)(1) = 0.00; constraints(2)(2) = 0.00;
		constraints(3)(0) = 0.00; constraints(3)(1) =-1.00; constraints(3)(2) = 0.00;

		var A:Rail[Rail[Double]] = Matrix.devideExpansionCoefficientMatrix1(constraints);
		var B:Rail[Double] = Matrix.devideExpansionCoefficientMatrix2(constraints);

		Console.OUT.println("*constraints");
		Console.OUT.println("**A");
		Matrix.dump(A);
		Console.OUT.println("**B");
		Matrix.dump(B);
		//原点を代入し，原点が制約条件を全て満たすことを確認.
		var initialValue:Rail[Double] =  Matrix.initialASM0(A,B);
		initialValue = Matrix.ActiveSetMethod(A,B,Q,C,initialValue);
		Console.OUT.println("*answer");	
		dump(initialValue );
		*/



	//　階段行列作成のテスト
	/*	val M = [
			[5.867404178383545, -1.424896853375735, -1.0, 0.0, 407.25093163595966, 3838.244757878670043 ],
			[-1.424896853375735, 30.067591377913473, 0.0, -1.0, 656.872669818089435, -43341.5631098544618 ],
			[-1.0, 0.0, 0.0, 0.0, 0.0, 0.0 ],
			[0.0, -1.0, 0.0, 0.0, 0.0, 0.0 ],
			[407.25093163595966, 656.872669818089435, 0.0, 0.0, 0.0, 0.0]
			];
		val n = M.size;
		val m = new Rail[Rail[Double]](n);
		for (i in 0..(n - 1)) {
			m(i) = new Rail[Double](M(i));
		}*/
		//Matrix.dump(m);
		//val lu:Rail[Rail[Double]] = Matrix.echelonForm(m);
	//シンプレックス法により，線形計画問題を解くテスト(LinearPrograming.java)
	/*	var n:Long = 2;
   		var m:Long = 3;
		var A:Rail[Rail[Double]] = new Rail[Rail[Double]](m);
		for(i in 0..(A.size-1) ){
			A(i) = new Rail[Double](n);
		}
		A(0)(0) = 1.00;  A(0)(1) = 2.00;
		A(1)(0) = 1.00;  A(1)(1) = 1.00;
		A(2)(0) = 3.00;  A(2)(1) = 1.00;
		Console.OUT.println("**A");
		Matrix.dump(A);

		var B:Rail[Double] = new Rail[Double](m);
		B(0) = 14.00;
		B(1) = 8.00;
		B(2) = 18.00;
		Console.OUT.println("**B");
		Matrix.dump(B);

		var obj:Rail[Double] = new Rail[Double](n);
		obj(0) = -2.00;
		obj(1) = -3.00;

		var co:Double = 0.00;
		var b:Rail[Double] =simplex(obj,co ,A,B);*/
	//シンプレックス法により，線形計画問題を解くテスト(http://suzuichibolgpg.blog.fc2.com/blog-entry-207.html)
/*		var n:Long = 2;
   		var m:Long = 2;
		var A:Rail[Rail[Double]] = new Rail[Rail[Double]](m);
		for(i in 0..(A.size-1) ){
			A(i) = new Rail[Double](n);
		}
		A(0)(0) = 2.00;  A(0)(1) = 8.00;
		A(1)(0) = 4.00;  A(1)(1) = 4.00;
		Console.OUT.println("**A");
		Matrix.dump(A);

		var B:Rail[Double] = new Rail[Double](m);
		B(0) = 60.00;
		B(1) = 60.00;
		Console.OUT.println("**B");
		Matrix.dump(B);

		var obj:Rail[Double] = new Rail[Double](n);
		obj(0) = -29;
		obj(1) = -45;

		var co:Double = 0.00;
		var b:Rail[Double] =simplex(obj,co ,A,B);
*/

	//2段階シンプレックス法により，線形計画問題を解くテスト(http://suzuichibolgpg.blog.fc2.com/blog-entry-208.html)
/*		var n:Long = 2;
   		var m:Long = 3;
		var A:Rail[Rail[Double]] = new Rail[Rail[Double]](m);
		for(i in 0..(A.size-1) ){
			A(i) = new Rail[Double](n);
		}
		A(0)(0) = -1.00;  A(0)(1) = 0.50;
		A(1)(0) = 1.00;  A(1)(1) = -1.00;
		A(2)(0) = 1.00;  A(2)(1) = 1.00;
		Console.OUT.println("**A");
		Matrix.dump(A);

		var B:Rail[Double] = new Rail[Double](m);
		var IES:Rail[Double] = new Rail[Double](m);
		IES(0) = -1.00;
		IES(1) = 1.00;
		IES(2) = 1.00;
		Console.OUT.println("**IES");
		Matrix.dump(IES);

		B(0) = -1.00;
		B(1) = 2.00;
		B(2) = 4.00;
		Console.OUT.println("**B");
		Matrix.dump(B);

		var obj:Rail[Double] = new Rail[Double](n);
		obj(0) = -2.00;
		obj(1) = -1.00;
		Console.OUT.println("**obj");
		Matrix.dump(obj);

		var co:Double = 0.00;
		var b:Rail[Double] =simplex(obj,co ,A,B);
		Console.OUT.println("**co");
		Console.OUT.println(co);		

		var b:Rail[Double] =simplex(obj,co,A,B,IES);
*/

	//有効制約法により二次計画問題を解くテスト: 誤算問題
	
		var Q:Rail[Rail[Double]] = new Rail[Rail[Double]](2);
		Q(0) = new Rail[Double](2);
		Q(1) = new Rail[Double](2);		
		Q(0)(0) = 3.491238029731011;		Q(0)(1) = -137.858285749715861;
		Q(1)(0) = -137.858285749715861;		Q(1)(1) = 456507.37103012681473;
		Console.OUT.println("============settings");
		Console.OUT.println("*FOC of objective function");
		Console.OUT.println("**Q");
		Matrix.dump(Q);

		val c = [-1.5029194602888158E10,-1.5029194602888158E10];

		var C:Rail[Double] = new Rail[Double](c.size);
		for(i in 0..(c.size-1)){
			C(i) =c(i);
		}
		Console.OUT.println("**C");
		Matrix.dump(C);
/*
		var constraints:Rail[Rail[Double]] = new Rail[Rail[Double]](7);
		for (i in 0..(constraints.size-1)) {
			constraints(i) = new Rail[Double](3);
		}
		constraints(0)(0) = -1.00; constraints(0)(1) = 0.00; constraints(0)(2) = 0.00;
		constraints(1)(0) = 0.00; constraints(1)(1) = -1.00; constraints(1)(2) = 0.00;
		constraints(2)(0) = 1.00; constraints(2)(1) = 0.00; constraints(2)(2) = 1.1258999068426241E15;
		constraints(3)(0) = 0.00; constraints(3)(1) =1.00; constraints(3)(2) = 1.1258999068426241E15;
		constraints(4)(0) = -1.00; constraints(4)(1) = 0.00; constraints(4)(2) = 1.1258999068426241E15;
		constraints(5)(0) = 0.00; constraints(5)(1) =-1.00; constraints(5)(2) = 1.1258999068426241E15;
		constraints(6)(0) = 9.352411165770475; constraints(6)(1) =3128.463420483581103; constraints(6)(2) = 9281203.443951873108745;
		var A:Rail[Rail[Double]] = Matrix.devideExpansionCoefficientMatrix1(constraints);
		var B:Rail[Double] = Matrix.devideExpansionCoefficientMatrix2(constraints);
*/

		var constraints:Rail[Rail[Double]] = new Rail[Rail[Double]](1);
		for (i in 0..(constraints.size-1)) {
			constraints(i) = new Rail[Double](3);
		}

		constraints(0)(0) = 9.352411165770475; constraints(0)(1) =3128.463420483581103; constraints(0)(2) = 9281203.443951873108745;
		var A:Rail[Rail[Double]] = Matrix.devideExpansionCoefficientMatrix1(constraints);
		var B:Rail[Double] = Matrix.devideExpansionCoefficientMatrix2(constraints);

		Console.OUT.println("*constraints");
		Console.OUT.println("**A");
		Matrix.dump(A);
		Console.OUT.println("**B");
		Matrix.dump(B);
		//原点を代入し，原点が制約条件を全て満たすことを確認.
		var initialValue:Rail[Double] =  Matrix.initialASM0(A,B);
		initialValue = Matrix.ActiveSetMethod(A,B,Q,C,initialValue);
		Console.OUT.println("*answer");	
		dump(initialValue );
		

		//var x:double = 0.0123456789;

		//x = Matrix.round(x,6);

	}
}

