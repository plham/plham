package plham.util;

/**
 * Brent's root-finding algorithm, which returns x in [a0,b0] s.t. f(x) = 0.
 * Reference: Numerical Recipes 3rd Ed, p.454.
 */
public class Brent {

	/**
	 * Brent's root-finding algorithm, which returns x in [a0,b0] s.t. f(x) = 0.
	 * Reference: Numerical Recipes 3rd Ed, p.454.
	 */
	public static def optimize(f:(Double)=>Double, a0:Double, b0:Double):Double {
		var a:Double = a0;
		var b:Double = b0;
		var c:Double = b0;
		var d:Double = 0.0;
		var e:Double = 0.0;
		var fa:Double = f(a);
		var fb:Double = f(b);
		var fc:Double = f(c);

		val epsilon = 1e-16;
		val tol = 1e-12;
		val maxiter = 500;

		if ((fa > 0.0 && fb > 0.0) || (fa < 0.0 && fb < 0.0)) {
			throw new NumericalException("two numbers must have different signs in a mapped space");
		}

		for (_ in 1..maxiter) {
			if ((fb > 0.0 && fc > 0.0) || (fb < 0.0 && fc < 0.0)) {
				c = a;
				fc = fa;
				e = d = b - a;
			}
			if (Math.abs(fc) < Math.abs(fb)) {
				a = b;
				b = c;
				c = a;
				fa = fb;
				fb = fc;
				fc = fa;
			}

			val tol1 = 2.0 * epsilon * Math.abs(b) + 0.5 * tol;
			val m = 0.5 * (c - b);
			if (Math.abs(m) <= tol1 || fb == 0.0) {
				return b;
			}
			var p:Double;
			var q:Double;
			var r:Double;
			var s:Double;
			if (Math.abs(e) >= tol1 && Math.abs(fa) > Math.abs(fb)) {
				s = fb / fa;
				if (a == c) {
					p = 2.0 * m * s;
					q = 1.0 - s;
				} else {
					q = fa / fc;
					r = fb / fc;
					p = s * (2.0 * m * q * (q - r) - (b - a) * (r - 1.0));
					q = (q - 1.0) * (r - 1.0) * (s - 1.0);
				}
				if (p > 0.0) {
					q = -q;
				}
				p = Math.abs(p);

				val m1 = 3.0 * m * q - Math.abs(tol1 * q);
				val m2 = Math.abs(e * q);
				if (2.0 * p < Math.min(m1, m2)) {
					e = d;
					d = p / q;
				} else {
					d = m;
					e = d;
				}
			} else {
				d = m;
				e = d;
			}
			a = b;
			fa = fb;
			if (Math.abs(d) > tol1) {
				b += d;
			} else {
				b += Math.copySign(tol1, m);
			}
			fb = f(b);
		}
		throw new NumericalException("a solution not found within a given bracket");
	}


	/**
	 * Brent's root-finding algorithm, which returns x in [a0,b0] s.t. f(x) = 0.
	 * Reference: Wikipedia.
	 */
	private static def optimize0(f:(Double)=>Double, a0:Double, b0:Double):Double {
		assert f(a0) * f(b0) <= 0.0 : [f, a0, b0, f(a0), f(b0)];
		val tol = 1e-9;

		var a:Double = a0;
		var b:Double = b0;
		var c:Double = a;
		var s:Double = b;
		var d:Double = Double.NaN;
		var fa:Double = f(a);
		var fb:Double = f(b);
		var fc:Double = f(c);
		var fs:Double = f(s);

		if (Math.abs(fa) < Math.abs(fb)) {
			val t = a;
			a = b;
			b = t;
		}

		var mflag:Boolean = true;
		
		var oldstate:Double = 0.0;
		while (!(fs == 0.0 || Math.abs(b - a) < tol)) {
			if (Math.abs(oldstate - Math.abs(b - a)) < tol * tol) {
				Console.OUT.println("Brent: not converged");
				return Double.NaN;
			}
			oldstate = Math.abs(b - a);
			if (fa != fc && fb != fc) {
				s = (a * fb * fc) / ((fa - fb) * (fa - fc))
				  + (b * fa * fc) / ((fb - fa) * (fb - fc))
				  + (c * fa * fb) / ((fc - fa) * (fc - fb));
			} else {
				s = b - fb * ((b - a) / (fb - fa));
			}

			val z = (3.0 * a + b) / 4.0;
			val bmin = Math.min(z, b);
			val bmax = Math.max(z, b);
			if ((s < bmin && s > bmax)
					|| ( mflag && Math.abs(s - b) >= Math.abs(b - c) / 2.0)
					|| (!mflag && Math.abs(s - b) >= Math.abs(c - d) / 2.0)
					|| ( mflag && Math.abs(b - c) < tol)
					|| (!mflag && Math.abs(c - d) < tol)) {
				s = (a + b) / 2.0;
				mflag = true;
			} else {
				mflag = false;
			}

			fs = f(s);
			d = c;
			c = b;

			if (fa * fs < 0.0) {
				b = s;
				fb = fs;
			} else {
				a = s;
				fa = fs;
			}

			if (Math.abs(fa) < Math.abs(fb)) {
				val t = a;
				a = b;
				b = t;
			}

			fa = f(a);
			fb = f(b);
			fc = f(c);
			fs = f(s);
		}
		return s;
	}

	public static def main(args:Rail[String]) {
		val f = (x:Double)=>(x + 3) * (x - 1) * (x - 1);
		val x = Brent.optimize(f, -4.0, 2.0);
		Console.OUT.println([x, f(x)]);
		val y = Brent.optimize(f, -4.0, 1.2);
		Console.OUT.println([y, f(y)]);
	}
}
