# Learn-OCaml/OFLAT integration - supporting FLAT concepts on Learn-OCaml


## About this Learn-OCaml branch

This is a Learn-OCaml branch that implements an experimental new feature: **the support of FLAT concepts on Learn-OCaml**. This is done in two ways: **(1)** adding support for text-based FLAT exercises inside Learn-OCaml; **(2)** connecting to a domain-specific external tool.




## Software elements

**Learn-OCaml** - is a Web platform for learning the OCaml language, featuring a toplevel and an environment with exercises, lessons and tutorials. [Project: https://gitlab.com/releaselab/leaf/OCamlFlat]

**OCamlFLAT** - is a OCaml library  with functions for several FLAT concept, e.g. testing acceptance, generating words; it also contains a basic text based environment supporting a toplevel and exercises. [Project: https://gitlab.com/releaselab/leaf/OCamlFlat].

**OFLAT** - is a purely client-side web-application that provides a graphical user interface to the OCamlFLAT library. [Project: https://gitlab.com/releaselab/leaf/OFLAT].

**Learn-OCaml/OFLAT integration** - this software solution for supporting FLAT concepts on Learn-OCaml.








## Supporting FLAT concepts on Learn-OCaml

### Part 1 - Text-based FLAT exercises in Learn-OCaml

- The implementation uses translation of exercises from the OCamlFLAT format to the Learn-OCaml format. The translator is implemented on the OCamlFLAT library, mostly inside the module "LearnOCaml.ml".

- The translated exercises are expressed using what is already available in Learn-OCaml. So, no change to the Learn-OCaml core was required for this feature. The expected student's solution for each translated exercise requires OCaml syntax.

- For each FLAT exercise, the translator generates a Learn-OCaml exercise directory containing all standard files: "descr.html", "prelude.ml", "solution.ml", "test.ml", "meta.json", "prepare.ml", "template.ml". As of now, the file "prepare.ml" contains the code of the entire OCamlFLAT library.

- In the current OCamlFLAT exercice format, the required student's answer is always a FLAT model. The student is asked to develop a FLAT model (for some informally or mathematically described language) or to convert between different kins of models. The exercise can impose further requisites like the requirement of the model to be deterministic or minimal, for example. The student's answer is validated using unit tests, followed by the direct checking of the extra requirements.

- The current exercise format caters for most frequent needs of the teacher, but some more exercise formats are in the works.

- Supporting this kind of text-based FLAT exercises does not require the use of the bridging facility.


### Part 2 - Bridging Learn-OCaml to external tools

- This branck adds a new bridge functionality on Learn-OCaml, the supports bidirectional communication with domain-specific external tools, such as OFLAT, that is specialized on FLAT concepts. The two sides of the bridge can transparently share and synchronize on what the student has done.

- The appropriate external tool is automatically selected and launched, according to some signature that occurs in the exercise specification. In the case of OFLAT, the signature is the specific comment "**(* OFLAT exercise *)**" occurring inside the file "solution.ml".

- The implementation uses the BroadcastChannel API. Therefore, the code of the external tool must reside in the same domain of the Learn-OCaml installation, as required by the same-origin policy. The external tools reside in the folder 'learn-ocaml/xtools', located at the root of the Learn-OCaml installation.

- The implementation of the bridge on the Learn-OCaml side is written in OCaml and mainly resides in the new source file "src/app/learnocaml_bridge.ml". Furthermore, some changes were required to the files "src/app/learnocaml_exercise_main.ml" and "src/app/dune".

- The implementation of the bridge on the  external tool side is currently written in JavaScript and resides in the module "OFLAT/XBridge.js".


### Part 3 - Bridge between Learn-OCaml and OFLAT, 

- When the user opens a FLAT exercise in LearnOCaml, OFLAT becomes automatically available as an external tool.

- The user interface of each side contains a button allowing the user to send data to the other side. For instance, the student defines a finite automaton on the graphical application and checks it on Learn-OCaml, and vice-versa.



## How to install

#### TODO

## Authors and Acknowledgements


#### TODO
