package de.ekut.wsi.abi.clinicalreporting.generator.model.observation;

import java.util.ArrayList;
import java.util.Arrays;
import java.util.List;

public class DefaultObservationContainer implements ObservationContainer {

	private final ObservationSchema schema;
	private final List<String[]> components;
	
	public DefaultObservationContainer(final ObservationSchema schema) {
		
		this.schema = schema;
		
		if (this.schema == null) {
			
			throw new NullPointerException("ObservationSchema must not be null!");
		}
		this.components = new ArrayList<>();
	}
	
	
	@Override
	public ObservationSchema getSchema() {
		
		return this.schema;
	}
	
	@Override
	public ObservationBuilder constructNewObservation() {
		
		return new DefaultObservationBuilder(new ObservationContainerHandle() {
			
			@Override
			public ObservationSchema getSchema() {
				
				return DefaultObservationContainer.this.getSchema();
			}
			
			@Override
			public void addComponent(final String[] component) {
				
				DefaultObservationContainer.this.components.add(Arrays.copyOf(component, component.length));
			}
		});
	}
}
