package de.ekut.wsi.abi.clinicalreporting.generator.model.observation;

import java.util.Arrays;

final class DefaultObservationBuilder implements ObservationBuilder {

	private final ObservationContainerHandle observationContainerHandle;
	private final String[] keys;
	private final String[] values;
	private final int size;
	private int index;

	DefaultObservationBuilder(final ObservationContainerHandle handle) {

		this.observationContainerHandle = handle;
		this.keys = handle.getSchema().getKeys();
		this.size = this.keys.length;
		this.values = new String[this.size];
		this.index = 0;
	}

	private void checkExhausted() {
		
		if (this.index >= this.size) {
			
			// TODO Message
			throw new IllegalStateException();
		}
	}

	@Override
	public String getKey() throws IllegalStateException {
		
		this.checkExhausted();
		return this.keys[this.index];
	}


	@Override
	public ObservationBuilder withNextAttribute(final String value) {
		
		this.checkExhausted();
		this.values[this.index++] = value;
		return this;
	}


	@Override
	public void build() {
	
		this.observationContainerHandle.addComponent(Arrays.copyOf(this.values, this.values.length));
	}
}