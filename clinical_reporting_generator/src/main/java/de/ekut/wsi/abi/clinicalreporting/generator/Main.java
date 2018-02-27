package de.ekut.wsi.abi.clinicalreporting.generator;

import java.io.BufferedReader;
import java.io.FileNotFoundException;
import java.io.FileReader;
import java.io.IOException;

import org.apache.commons.cli.CommandLine;
import org.apache.commons.cli.DefaultParser;
import org.apache.commons.cli.Options;
import org.apache.commons.cli.ParseException;
import org.docx4j.model.table.TblFactory;
import org.docx4j.openpackaging.exceptions.Docx4JException;
import org.docx4j.openpackaging.packages.WordprocessingMLPackage;
import org.json.JSONObject;

import com.fasterxml.jackson.databind.exc.InvalidFormatException;

import de.ekut.wsi.abi.clinicalreporting.generator.model.document.DocumentTree;
import de.ekut.wsi.abi.clinicalreporting.generator.model.document.DocumentTreeNode;
import de.ekut.wsi.abi.clinicalreporting.generator.model.docx4j.DocumentGenerator;
import de.ekut.wsi.abi.clinicalreporting.generator.model.traversal.PreorderTraversal;


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

				final DocumentTreeNode documentTree = DocumentTree.parse(new JSONObject(builder.toString()));


				// Create the output package
				final WordprocessingMLPackage wordMLPackage = WordprocessingMLPackage.createPackage();
				new DocumentGenerator(documentTree).generate(wordMLPackage);

				 wordMLPackage.save(new java.io.File(outputFile) );

			} catch (FileNotFoundException e) {
				
				
				e.printStackTrace();
			} catch (IOException e) {
				
				e.printStackTrace();
				
			} catch (org.docx4j.openpackaging.exceptions.InvalidFormatException e) {
				
				e.printStackTrace();
				
			} catch (Docx4JException e) {
				
				e.printStackTrace();
			} 

		} catch(final ParseException e) {

			System.err.println("FATAL: Could not parse command line arguments due to:" + e.getMessage());
			System.exit(1);
		}
	}	
}
