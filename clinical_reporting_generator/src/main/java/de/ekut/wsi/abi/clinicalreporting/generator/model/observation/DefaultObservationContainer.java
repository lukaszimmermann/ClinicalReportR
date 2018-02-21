package de.ekut.wsi.abi.clinicalreporting.generator.model.observation;

import java.util.ArrayList;
import java.util.Arrays;
import java.util.List;

import de.ekut.wsi.abi.clinicalreporting.generator.model.assertions.Assert;

public class DefaultObservationContainer implements ObservationContainer {

	private final ObservationSchema schema;
	private final List<String[]> components;
	
	public DefaultObservationContainer(final ObservationSchema schema) {
		
		this.schema = schema;
		
		Assert.notNull(this.schema, "ObservationSchema must not be null!");
		this.components = new ArrayList<>();
	}
	
	@Override
	public int numObservations() {
		
		return this.components.size();
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

	@Override
	public List<String[]> getRawObservations() {
		
		final List<String[]> res = new ArrayList<>();
		
		for (final String[] component : this.components) {
			
			res.add(Arrays.copyOf(component, component.length));
		}
		return res;
	}
}
