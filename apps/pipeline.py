#!/usr/bin/env python3
import sys
import argparse
import os
import subprocess


# File Extensions
FILE_EXTENSION_VCF = '.vcf'
FILE_EXTENSION_ANNOTATED_VCF= '.annotated.vcf'

########## PARAMETER HANDLING #############################################
PARAM_EXECUTABLE_VEP = 'executable-vep'
PARAM_EXECUTABLE_REPORTING  = 'executable-reporting'
PARAM_EXECUTABLE_TEMPLATING = 'executable-templater'
PARAM_DIRECTORY_VCF = 'vcf-dir'

PARAMS = [
    PARAM_EXECUTABLE_VEP,
    PARAM_EXECUTABLE_REPORTING,
    PARAM_EXECUTABLE_TEMPLATING,
    PARAM_DIRECTORY_VCF
]

########## HELPER FUNCTIONS #################################################

def is_annotated_vcf(filename):
    return filename.endswith(FILE_EXTENSION_ANNOTATED_VCF)


def is_non_annotated_vcf(filename):
    return filename.endswith(FILE_EXTENSION_VCF) and not is_annotated_vcf(filename)


def fatal_if(test, msg, exit_code):
    if test:
        print("FATAL: " + msg, file=sys.stderr)
        sys.exit(exit_code)

def fatal_if_not_regular_file(filename):
    fatal_if(
        not os.path.isfile(filename),
        "Not a regular file: {}".format(filename), 1)

def fatal_if_not_directory(filename):
    fatal_if(
        not os.path.isdir(filename),
        "Not a directory: {}".format(filename), 2)


def remove_if_exists(filename):
    if os.path.exists(filename):
        os.remove(filename)


###############################################################################

def prepare_in_out(basename, input_extension, output_extension):

    input_file = basename + "." + input_extension
    output_file  = basename + "." + output_extension
    remove_if_exists(output_file)
    exit_if(not os.path.exists(input_file), "Input file does not exist", 2)
    return (input_file, output_file)

###############################################################################

def parse_args():
    parser = argparse.ArgumentParser()
    for param in PARAMS:
        parser.add_argument('--' + param, type=str, required=True)
    args = parser.parse_args()

    # Parameter Validation
    fatal_if_not_regular_file(args[PARAM_EXECUTABLE_VEP])
    fatal_if_not_regular_file(args[PARAM_EXECUTABLE_REPORTING])
    fatal_if_not_regular_file(args[PARAM_EXECUTABLE_TEMPLATING])
    fatal_if_not_directory(args[PARAM_DIRECTORY_VCF])
    return args


def process(*commands):
    print("Executing: " + ' '.join(commands))
    my_env = os.environ.copy()
    my_env["PERL5PATH"] = "/opt/vep/.vep/Plugins/loftee-0.3-beta"
    process = subprocess.Popen(commands, env=my_env)
    process.communicate()
    return process.wait()


def prefix(filename):
    """
    Removes the file extension of the file
    """
    file_ext = [ ".annotated.vcf", ".vcf", ".docx", ".doc", ".pdf", ".json"]
    for ext in file_ext:
        if filename.endswith(ext):
            return filename[:-len(ext)]
    return filename


########## Indiviudal pipeline steps ##########################################

def generate_vcf_files(directory):
    # Lists all the VCF files that should be generated
    files = [ os.path.join(directory, x)
                for x in os.listdir(x) if is_non_annotated_vcf(x) ]
    print("Processing the following VCF files:")
    for file in files:
        print(file)
    for file in files:
        yield file

def announce(f):
    print("Now processing file: {}".format(f))


def main():
    args = parse_args()

    # Generate the not annotated vcf file
    for vcf_file in generate_not_annotated_vcf_files(args[PARAM_DIRECTORY_VCF]):
        announce(vcf_file)
        basename = prefix(vcf_file)



    # vcf_files_dir = '/inout'
    # print("Looking for VCF files in the following container directory: {}".format(vcf_files_dir))
    # vcf_files = list_unannotated_vcf_files(vcf_files_dir)
    #
    # print_sep1()
    # print("Processing the following files: ")
    # print_sep2()
    # for vcf_file in vcf_files:
    #     print(vcf_file)
    # print_sep1()
    #
    # # Process each of the files in turn
    # for vcf_file in vcf_files:
    #    print("Processing: {}".format(vcf_file))
    #    base_name = remove_extension(vcf_file)
    #
    #    # Step: VCF
    #    (inpt, out) = prepare_in_out(base_name, 'vcf', 'annotated.vcf')
    #    result = process('/opt/vep/src/ensembl-vep/vep', '-i', inpt, '-o', out, '--config', '/opt/vep.ini')
    #
    #    # Step: Generation of data for report
    #    (inpt, out) = prepare_in_out(base_name, 'annotated.vcf', 'json')
    #    result = process("Rscript",
    #                     "--no-save",
    #                     "--no-restore",
    #                     "--no-init-file",
    #                     "--no-site-file",
    #                     "/opt/reporting/reporting.R", "-f", inpt, "-r", out)
    #
    #    # Step: Reporting:
    #    (inpt, out) = prepare_in_out(base_name, 'json', 'docx')
    #    result = process("/usr/bin/nodejs",
    #                     "/opt/templater/main.js",
    #                     "-d", inpt,
    #                     "-t", "/opt/templater/data/template.docx",
    #                     "-o",  out)
    #    print_sep2()


if __name__ == '__main__':
    main()
