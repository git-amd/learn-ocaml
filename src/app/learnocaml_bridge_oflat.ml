(* This file is part of Learn-OCaml.
 *
 * Copyright (C) 2019 OCaml Software Foundation.
 * Copyright (C) 2016-2018 OCamlPro.
 *
 * Learn-OCaml is distributed under the terms of the MIT license. See the
 * included LICENSE file for details. *)

(* ---------------------------------------------------------------------------
	learnocaml_bridge_oflat file

	This code was developed in the context of the LEAFS project.
	The LEAFS project was partially supported by the OCaml Software
	Foundation [2020/21]

	NOVA LINCS - NOVA Laboratory for Computer Science and Informatics
	Dept. de Informática, FCT, Universidade Nova de Lisboa, Portugal

	Written by Artur Miguel Dias (amd) and Rita Macedo (rm) with
	helpful feedback of Yann Régis-Gianas, Kim Nguyễn, António Ravara
	and Simão Sousa
 --------------------------------------------------------------------------- *)


(* ---------------------------------------------------------------------------
	General description:

	This source file implements a bridge to the xtool (external tool) OFLAT.

	This source file contains:
		- instanciation of the Bridge functor for OFLAT
		- the registration of the OFLAT bridge
		- installation instructions for OFLAT, to be used by the Learn-OCaml
			installation administrator
 --------------------------------------------------------------------------- *)


(* ---------------------------------------------------------------------------
  OFlatBridge

  Bridge to the OFLAT xtool
 --------------------------------------------------------------------------- *)

open Learnocaml_bridge

(*	Configuration for OFLAT *)
module OFlatBridgeConfig =
struct
	include AceMixin
	include UserInteractionMixin

	let name = "OFLAT"
	let url = "http://localhost:8080/static/xtools/OFLAT/index.html?learn-ocaml"
	let channelName = "oflat_channel"
end

(*	Instantiate the Bridge functor for OFLAT *)
module OFlatBridge =
	Bridge(OFlatBridgeConfig)


(* ---------------------------------------------------------------------------
  Registration
 --------------------------------------------------------------------------- *)

(*	Register the OFLAT bridge. Note that the flat '-linkall' must be activated
	in the dune configuration for this to work. *)
let initialization =
	BridgeRegistry.register "(* OCamlFlat exercise *)" OFlatBridge.setup;
	BridgeRegistry.register "(* OFLAT exercise *)" OFlatBridge.setup


(* ---------------------------------------------------------------------------
  Installation instructions for the xtool OFLAT:

   The code of any xtool must reside inside the Learn-OCaml
   installation, as required by the same-origin policy.
   All the xtools reside in the folder 'learn-ocaml/xtools',
   located at  the root of the Learn-OCaml installation.

   - Prerequisite - build Learn-OCaml and create your exercise repository:

		make && make opaminstall
		learn-ocaml build --repo my-learn-ocaml-repository

   - Installation instructions for OFLAT:

		cd learn-ocaml   # <- ADJUST THIS LINE; cd to the root of the installation
		mkdir -p xtools/OFLAT
		rm -f xtools/OFLAT/*				# cater for reinstallation
		wget  -r -nd -nv http://ctp.di.fct.unl.pt/LEAFS/OFLAT/ -P xtools/OFLAT
		ln -sr ../www . 2>/dev/null		# sometimes www is not where we expected it to be
		ln -srf xtools www/static

     Note: This installation is allowed to be performed multiple times, for example
     to update the xtool to a new version.

 --------------------------------------------------------------------------- *)


