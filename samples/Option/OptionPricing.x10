
public class OptionPricing {

	public double Call(S:Double, K:Double, Vol:Double, T:Double, r:Double, d:Double){
	if(T <= 0.000001d) {
		return Math.max(0.0, S-K);
	}else{
		//System.out.println("@call");
		double call = S*normsdist(d1(S,K,Vol,T,r,d))-K*Math.exp(-r*T)*normsdist(d2(S,K,Vol,T,r,d));
		if(call <= 0){
			call = 0.001d;
		}
		//System.out.println("@call finish");
		return call;
		}
	}

}
