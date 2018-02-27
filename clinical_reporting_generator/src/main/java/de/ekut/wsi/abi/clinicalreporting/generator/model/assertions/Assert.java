package de.ekut.wsi.abi.clinicalreporting.generator.model.assertions;

public final class Assert {

	private Assert() {
		
		throw new AssertionError();
	}
	
	public static void notNull(final Object o, final String message) {
		
		if (o == null) {
			
			throw new NullPointerException(message);
		}
	}
}
