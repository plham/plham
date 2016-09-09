package plham.util;
import plham.util.NumericalException;

/**
 * Newton's root-finding algorithm, which returns x s.t. f(x) = 0.
 * The implementation actually is Secant method, without derivative.
 * TODO: Newton-Raphson's gradient algorithm.
 * Reference: https://en.wikipedia.org/wiki/Secant_method
 * Reference: https://github.com/scipy/scipy/blob/v0.17.0/scipy/optimize/zeros.py#L66-L184
 */
public class Newton {

	public static def optimize(f:(Double)=>Double, x0:Double):Double {
		val tol = 1.48e-8;
		val maxiter = 50;
		return optimize(f, x0, tol, maxiter);
	}

	public static def optimize(f:(Double)=>Double, x0:Double, tol:Double, maxiter:Long):Double {
		// Secant method
		var p0:Double, p1:Double;
		var q0:Double, q1:Double;
		var p:Double = 0;

		p0 = x0;
		if (x0 >= 0) {
			p1 = x0 * (1 + 1e-4) + 1e-4;
		} else {
			p1 = x0 * (1 + 1e-4) - 1e-4;
		}
		q0 = f(p0);
		q1 = f(p1);
		for (t in 1..maxiter) {
			if (q1 == q0) {
				if (p1 != p0) {
					Console.ERR.println("NewtonRaphson: Tolerance of " + (p1 - p0) + " reached");
				}
				return (p1 + p0)/2.0;
			} else {
				p = p1 - q1 * (p1 - p0)/(q1 - q0);
			}
			if (Math.abs(p - p1) < tol) {
				return p;
			}
			p0 = p1;
			q0 = q1;
			p1 = p;
			q1 = f(p1);
		}
		throw new NumericalException("Failed to converge after " + maxiter + " iterations, value is " + p);
	}

	public static def main(Rail[String]) {
		val a = 4;
		val x0 = 0.123;
		val x1 = Newton.optimize((x:Double) => x * x - a, +x0);
		val x2 = Newton.optimize((x:Double) => x * x - a, -x0);
		val x3 = Newton.optimize((x:Double) => (x - a) * (x - a), +x0);
		val x4 = Newton.optimize((x:Double) => (x - a) * (x - a), -x0);
		Console.OUT.println("f(x) = x * x - a");
		Console.OUT.println("Optimal: " + x1 + " from " + (+x0));
		Console.OUT.println("Optimal: " + x2 + " from " + (-x0));
		Console.OUT.println("f(x) = (x - a)**2");
		Console.OUT.println("Optimal: " + x3 + " from " + (+x0));
		Console.OUT.println("Optimal: " + x4 + " from " + (-x0));
	}
}
