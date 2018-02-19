package de.ekut.wsi.abi.clinicalreporting.generator;

import org.apache.commons.cli.Option;

public final class CLIUtils {

	private CLIUtils() {
		
		throw new AssertionError();
	}
	
	static Option createFileOption(final String name, final String argName, final String description) {
		
		final Option fileOption = new Option(name, true, description);
		fileOption.setArgs(1);
		fileOption.setArgName(argName);
		fileOption.setRequired(true);
		return fileOption;
	}
}
