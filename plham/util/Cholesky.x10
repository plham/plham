package plham.util;


/**
 * Cholesky decomposition of a positive definite matrix.
 * Reference: Numerical Recipes 3rd Ed, p.100.
 */
public class Cholesky {

	/**
	 * Cholesky decomposition of a positive definite matrix.
	 * It returns a new array whose lower-triangular store the factors, and
	 * whose upper-triangular are all zero.
	 * Reference: Numerical Recipes 3rd Ed, p.100.
	 */
	public static def decompose(m:Rail[Rail[Double]]):Rail[Rail[Double]] {
		val n = m.size;
		val a = new Rail[Rail[Double]](n);
		for (i in 0..(n - 1)) {
			a(i) = new Rail[Double](m(i));
		}
		var sum:Double;
		for (i in 0..(n - 1)) {
			assert a(i).size == n;
			for (j in i..(n - 1)) {
				sum = a(i)(j);
				for (k in 0..(i - 1)) {
					sum -= a(i)(k) * a(j)(k);
				}
				if (i == j) {
					if (sum <= 0.0) {
						throw new NumericalException("a matrix is not positive definite");
					}
					a(i)(i) = Math.sqrt(sum);
				} else {
					a(j)(i) = sum / a(i)(i);
				}
			}
		}
		for (i in 0..(n - 1)) {
			for (j in 0..(i - 1)) {
				a(j)(i) = 0.0;
			}
		}
		return a;
	}

	public static def main(Rail[String]) {
//		val M = [
//			[ 1.0,  0.8,  0.0],
//			[ 0.8,  1.0,  0.0],
//			[ 0.0,  0.0,  1.0]
//		];
		/* is decomposed to:
		 * [[ 1.   0.   0. ]
		 *  [ 0.8  0.6  0. ]
		 *  [ 0.   0.   1. ]]
		 */
//		val M = [
//			[ 1.0,  0.8,  0.0,  0.0],
//			[ 0.8,  1.0,  0.0,  0.0],
//			[ 0.0,  0.0,  1.0, -0.8],
//			[ 0.0,  0.0, -0.8,  1.0]
//		];
		/* ==>
		 * [[ 1.   0.   0.   0. ]
		 *  [ 0.8  0.6  0.   0. ]
		 *  [ 0.   0.   1.  -0. ]
		 *  [ 0.   0.  -0.8  0.6]]
		 */
//		val M = [
//			[ 1.        , -0.65568966,  0.80044528],
//			[-0.65568966,  1.        , -0.577069  ],
//			[ 0.80044528, -0.577069  ,  1.        ]
//		];
		/* ==>
		 * [[ 1.         -0.          0.        ]
		 *  [-0.65568966  0.75503051 -0.        ]
		 *  [ 0.80044528 -0.0691698   0.59540146]]
		 */
		val M = [
			[ 1.        , -0.84282638,  0.20007618],
			[-0.84282638,  1.        ,  0.84461232],
			[ 0.20007618,  0.84461232,  1.        ]
		];
		/* ==>
		 * Not positive definite!
		 */

		val n = M.size;
		val m = new Rail[Rail[Double]](n);
		for (i in 0..(n - 1)) {
			m(i) = new Rail[Double](M(i));
		}
		Console.OUT.println(m.typeName());
		Console.OUT.println(m);
		val a = decompose(m);
		Console.OUT.println(a);
	}
}
