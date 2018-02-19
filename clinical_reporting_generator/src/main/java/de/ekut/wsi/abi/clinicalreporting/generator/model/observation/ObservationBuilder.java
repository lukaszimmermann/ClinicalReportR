package de.ekut.wsi.abi.clinicalreporting.generator.model.observation;

public interface ObservationBuilder {

	/**
	 * Gets the key that the ObservationKeySetter is expecting next
	 * @return
	 */
	String getKey() throws IllegalStateException;
	
	ObservationBuilder withNextAttribute(final String value);
	
	// TODO Change Return type to observation
	void build();
}
