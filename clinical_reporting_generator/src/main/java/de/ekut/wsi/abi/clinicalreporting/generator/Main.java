package de.ekut.wsi.abi.clinicalreporting.generator;

import java.awt.image.BufferedImageFilter;
import java.io.BufferedReader;
import java.io.FileNotFoundException;
import java.io.FileReader;
import java.io.IOException;
import java.nio.file.Path;
import java.nio.file.Paths;

import org.apache.commons.cli.CommandLine;
import org.apache.commons.cli.DefaultParser;
import org.apache.commons.cli.Options;
import org.apache.commons.cli.ParseException;
import org.json.JSONArray;
import org.json.JSONObject;

import com.fasterxml.jackson.core.JsonParser;


/**
 * Entrypoint of the  Clinical Report Generator Application
 * 
 * @author lukaszimmermann
 *
 */
public final class Main {

	// Prevent instantiation
	private Main() {
		
		throw new AssertionError();
	}
		
	public static void main(final String[] args) {
		
		final String inputFlag = "i";
		final String outputFlag = "o";
		
		final Options options = new Options();
		options.addOption(CLIUtils.createFileOption(inputFlag, "<input.json>", "JSON File to create the clinical report from"));
		options.addOption(CLIUtils.createFileOption(outputFlag, "<output.docx>", "DOCX Clinical Report"));
		
		try {
		
			final CommandLine commandLine = new DefaultParser().parse(options, args);
			final String inputFile = commandLine.getOptionValue(inputFlag);
			final String outputFile = commandLine.getOptionValue(outputFlag);
			
			// Read the JSON object
			final StringBuilder builder = new StringBuilder();
			try (final BufferedReader fileReader = new BufferedReader(new FileReader(inputFile))) {
				
				String line;
				while ((line = fileReader.readLine()) != null) {
					
					builder.append(line);
				}
				
				final JSONObject jsonObject = new JSONObject(builder.toString());
				
			
			} catch (FileNotFoundException e) {
				// TODO Auto-generated catch block
				e.printStackTrace();
			} catch (IOException e) {
				// TODO Auto-generated catch block
				e.printStackTrace();
			}
				
			
			
		} catch(final ParseException e) {
		
			System.err.println("FATAL: Could not parse command line arguments due to:" + e.getMessage());
			System.exit(1);
		}
	}	
}
