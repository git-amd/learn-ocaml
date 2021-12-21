(* This file is part of Learn-OCaml.
 *
 * Copyright (C) 2019 OCaml Software Foundation.
 * Copyright (C) 2016-2018 OCamlPro.
 *
 * Learn-OCaml is distributed under the terms of the MIT license. See the
 * included LICENSE file for details. *)

(* ---------------------------------------------------------------------------
	learnocaml_bridge file

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
	General description

	This source file implements a bridge to an external web app (herein
	called xtool or external tool).

	Using the bridge functionality, Learn-OCaml is able to launch an xtool
	suitable for the currently open exercise. After the xtool is opened,
	the communication between the main application and the xtool is
	bidirectional. Any side can take the initiative to send some data
	to the other side.

	The code of the xtool must reside inside the Learn-OCaml installation,
	as required by the same-origin policy. All the xtools reside in the
	folder 'learn-ocaml/xtools', located at the root of the Learn-OCaml
	installation. The installation rules for each xtool are available in
	the file implementing the corresponding bridge. For an example,
	check the file 'learnocaml_bridge_oflat.ml'.

 [TABSTOPS=4]
 --------------------------------------------------------------------------- *)


(* ---------------------------------------------------------------------------
	MyBroadcastChannel

	OCaml bindings for the Broadcast Channel API.

	The latest HTML5 specification is called HTML Living Standard. This is the
	section concerning the Broadcast Channel API:

	https://html.spec.whatwg.org/multipage/web-messaging.html#broadcasting-to-other-browsing-contexts
 --------------------------------------------------------------------------- *)

module MyBroadcastChannel =
struct
	open Js_of_ocaml

	let constr =		(* constructor *)
		Js.Unsafe.global##._BroadcastChannel

	let isSupported () =	(* check if the browser supports the BC API *)
		Js.Optdef.test constr

	let create name =		(* create new broadcast channel object *)
		new%js constr (Js.string name)

	let close bc = 			(* close broadcast channel object *)
		ignore (bc##close())

	let name bc = 			(* get the name of broadcast channel object *)
		Js.to_string (bc##.name)

	let post bc message = 	(* send message though a broadcast channel object *)
		ignore (bc##postMessage (Js.string message))

	let on bc f =			(* broadcast channel object event handler *)
		bc##.onmessage := Dom.handler f
end


(* ---------------------------------------------------------------------------
	Bridge

	Bridge from the main app to an xtool.

	Bridge is a functor that depends only on js_of_ocaml and on the Broadcast
	Channel API. The functor parameter allows for specifying data or
	operations concerning the specific xtool and concerning Learn-OCaml.

	Functionalities:
	- Launch an xtool
	- Support bidirectional communication with the xtool
	- Ensure ownership of a particular xtool instance
	- Reuse a fortuitous xtool instance left over from a previous execution
	- Install interaction widgets in the main application user interface
 --------------------------------------------------------------------------- *)

module type BridgeConfigSig =			(* The Bridge parameter type *)
sig
	val name : string					(* the name of the xtool *)
	val url : string					(* the url of the xtool *)
	val channelName : string			(* the chosen channel name *)

	val toSend : unit -> string			(* decide what text to send to the other side *)
	val receive : string -> unit		(* process the text received from the other side *)
	val setupUserInteraction : string -> (unit -> unit Lwt.t) -> unit
										(* usually, install some gui widget *)
end

module type BridgeSig =					(* The Bridge public type *)
sig
	val setup : unit -> unit		(* activate the Bridge *)
end

module Bridge(Config : BridgeConfigSig) : BridgeSig =	(* The Bridge functor *)
struct
	open Js_of_ocaml

  (* -- Warning messages -- *)

	let warning mesg =
		ignore (Js.Unsafe.global##alert (Js.string (mesg)))

	let warnNoBroadcastChannel () =
		let m1 = "This Web browser does not support the Broadcast Channel API.\n\n" in
		let m2 = "The external tool " ^ Config.name ^
							" will not be available in this session." in
			warning (m1 ^ m2)

	let warnNotInstalled () =
		let m1 = "The external tool " ^ Config.name ^
							" has not been installed yet.\n\n" in
		let m2 = "Ask the manager of your site to install it.\n" in
			warning (m1 ^ m2)


  (* -- Lwt functions -- *)

	(* Lwt bind operator *)
	let (>>=) = Lwt.(>>=)

	(* Non-blocking delay *)
	let delay n =
		Js_of_ocaml_lwt.Lwt_js.sleep (float_of_int n *. 0.01)


  (* -- Status of the xtool -- *)

	(* Each Bridge owns an xtool instance. The reference xtoolAlive tell us
		if the xtool is currently open and loaded in the web browser.
		We can send requests to the xtool only when the xtool is alive. *)
	let xtoolAlive =
		ref false

	let isXToolAlive () =
		!xtoolAlive

	let setXToolAlive b =
		xtoolAlive := b


  (* -- The broadcast channel connects the main app to the xtool -- *)

	(* The broadcast channel reference *)
	let bcRef : 'a Js_of_ocaml.Js.t option ref =
		ref None

	(* Get the broadcast channel in use *)
	let bc () =
		match !bcRef with
		| Some bc -> bc
		| None -> failwith "BC API unavailable"

	(* Callback function: Receiving a message from the xtool *)
	let receive ev =
		let text = Js.to_string ev##.data in
			if text = "rendezvous"	(* handle special reply to ping *)
			then setXToolAlive true (* resurrect an old fortuitous instance *)
			else Config.receive text; (* otherwise, handle a regular message *)
			Js._true

	(* Sending a message to the xtool *)
	(* pre: isXToolAlive () *)
	let send () = 
		let text = Config.toSend () in
			MyBroadcastChannel.post (bc()) text;
			Lwt.return_unit

	(* Setup the broadcast channel object *)
	let openChannel () =
		if !bcRef = None then
			let chan = MyBroadcastChannel.create Config.channelName in
				MyBroadcastChannel.on chan receive;	(* install the callback *)
				bcRef := Some chan


  (* -- Try to reuse a fortuitous old instance of the xtool -- *)

	(* If there is a running xtool instance from a prev. execution, then reuse it.
		To check if there is an old instance open in the browser, the protocol
		consists in exchanging the message "rendezvous" in both directions. The
		function 'tryToReuse' sends the message; the reply is handled
		inside the function 'receive' *)
	let tryToReuse () =
		MyBroadcastChannel.post (bc()) "rendezvous"; (* ping the xtool *)
		delay 20		(* small time allowance for the old instance to reply *)
						(* no reply means no old instance available *)


  (* -- Launch and initialize a fresh instance of the xtool -- *)

	(* Creates an xtool instance that is owned by the main app.
		Event handlers are installed to detect the moment the xtool gets
		fully loaded and also the moment xtool is unloaded (because the user
		closed the xtool window).

		Regarding the installation of the event handlers, unfortunately
		w##.onload := ... did not work, but fortunately, addEventListener
		did work. *)

	(* Create fresh instance of the xtool *)
	(* pre: not (isXToolAlive ()) *)
	let freshXTool () =
		let wOpt =
			Dom_html.window##open_
				(Js.string Config.url)
				(Js.string "_blank")
				(Js.some (Js.string ""))	(* Js.null works on Chrome but not on Firefox *)
		in
			Js.Opt.get wOpt (fun () -> (* never fails because of js_of_ocaml oddity *)
				failwith ("freshXTool: " ^ Config.name ^ " failed to open"))

	(* Install the on_load listener. Notice the use of 'setXToolAlive true' *)
	let installLoadEventListener w =
		Dom_html.addEventListener
			w
			Dom_html.Event.load
			(Dom_html.handler (fun _ -> setXToolAlive true; Js._true))
			Js._true
		
	(* Install the on_unload listener. Notice the use of 'setXToolAlive false' *)
	let installUnloadEventListener w =
		Dom_html.addEventListener
			w
			Dom_html.Event.unload
			(Dom_html.handler (fun _ -> setXToolAlive false; Js._true))
			Js._true

	(* Non-blocking wait for the xtool to be fully loaded *)
	(* pre: not (isXToolAlive ()) *)
	let rec waitForAlive () =
		if isXToolAlive ()
		then Lwt.return_unit
		else delay 2 >>= fun _ -> waitForAlive ()

	(* Launch and setup new instance of the xtool *)
	(* pre: not (isXToolAlive ()) *)
	let launchXTool () =
		let w = freshXTool () in (* create a fresh instance *)
		let _ = installLoadEventListener w in (* install the listeners *)
		let _ = installUnloadEventListener w in
			waitForAlive ()	(* wait for the load event *)
			>>= fun _ ->
					Lwt.return w


  (* -- Continuously, make sure that the xtool is loaded -- *)

	(*	Oddity: In case the xtool has not been installed in Learn-OCaml,
		then method window##open_ (called in 'freshXTool') always succeed with
		some dummy page open in the browser. This is how js_of_ocaml works.
		So, we need to look at the title of the open document to
		check if it really corresponds to the xtool. The title of the dummy
		page is the empty string. *)
	let titleOfDummyPage = ""

	(* Check the availability of the xtool by looking at the title of the open page *)
	let confirmXTool w = 
		if Js.to_string w##.document##.title = titleOfDummyPage then begin
			w##close;	(* close the dummy page *)
			warnNotInstalled ()
		end;
		Lwt.return_unit

	(* Logic to keep the xtool always loaded *)
	let ensureXToolIsAlive () =
		openChannel ();	(* the channel is lazily opened *)
		if isXToolAlive ()	(* is the xtool already alive? *)
		then Lwt.return_unit (* if so, done! *)
		else
			tryToReuse ()	(* tries to resurrect an old xtool instance *)
			>>= fun _ ->
				if isXToolAlive ()	(* has been resurrected? *)
				then Lwt.return_unit (* if so, done! *)
				else
					launchXTool () (* launch a fresh xtool instance *)
					>>= fun w ->
						confirmXTool w (* confirm if it is the xtool *)

	(* Sending a message, while ensuring the xtool is alive *)
	let safeSend () =
		if MyBroadcastChannel.isSupported () then
			ensureXToolIsAlive ()	(* the xtool is lazily opened *)
			>>= fun _ ->
					send ()
		else
			(warnNoBroadcastChannel (); Lwt.return_unit)


  (* -- Setup the Bridge functor instance -- *)

	(* Setup the user interface concerning the xtool, inside the main application.
		Do not launch the xtool yet. The xtool will be launched lazily in the
		'safeSend' function. If there is a gui widget associated with xtool,
		then the user clicking in the widget should normally result in the
		function 'safeSend' being called. *)
	let setup () =
		Config.setupUserInteraction Config.name safeSend
end


(* ---------------------------------------------------------------------------
	BridgeRegistry

	This module associates bridges to xtools.

	All available bridges should be registered using BridgeRegistry.register.
	For an example of registration, check the source file 'learnocaml_bridge_oflat.ml'.

	The method 'BridgeRegistry.selectAndRun' is called from the Learn-OCaml code
	to perform the automatic activation of the right bridge for a specific exercise.
 --------------------------------------------------------------------------- *)

module type BridgeRegistrySig =					(* The BridgeRegistry public type *)
sig
	val register: string -> (unit -> unit) -> unit
	val selectAndRun: string  -> unit
end

module BridgeRegistry : BridgeRegistrySig =		(* The BridgeRegistry module *)
struct
	(*	This table associates signature strings with bridge launchers *) 
	let registry: (string * (unit->unit)) list ref =
		ref []

	(*	Register a bridge launcher *) 
	let register signature launcher =
		registry := (signature, launcher)::!registry

	(*	Extract the xtool signature from an exercise solution *) 
	let extractSignature solution =
		let newlinePos = String.index_from solution 0 '\n' in (* get first line *)
			String.sub solution 0 newlinePos

	(* The method 'selectAndRun' must be called from the 'Learnocaml_exercise_main' module,
		after opening an exercise in the Learn-OCaml user interface. The argument is the
		source code of the solution to the exercise. *)
	(* pre: all the xtools are already registered using initialization code in
		the corresponding modules *)
	let selectAndRun solution =
		let signature = extractSignature solution in (* examines the solution file *)
			match List.assoc_opt signature !registry with (* select *)
			| None -> ()
			| Some launcher -> launcher ()	(* run the correct bridge *)
end


(* ---------------------------------------------------------------------------
	Bridge configuration utilities

	Some building blocks to help create bridge configurations (that is the Bridge
	functor parameters). For an example, check 'learnocaml_bridge_oflat.ml'.

	The method 'Learnocaml_bridge.AceMixin.setAce' is called from the Learn-OCaml code
	to make the Ace editor panel accessible to the bridge configurations than need it.
 --------------------------------------------------------------------------- *)

module NullMixin : BridgeConfigSig =	(* Example of "null" bridge configuration *)
struct
	let name = ""
	let url = ""
	let channelName = ""
	let toSend () = ""
	let receive _ = ()
	let setupUserInteraction _ _ = ()
end

module AceMixin : sig	(* Supply Ace functionality to the bridges needing it *)
	type aceType = Ocaml_mode.editor Ace.editor
	val setAce : aceType -> unit
	val toSend : unit -> string
	val receive : string -> unit
end
=
struct
    open Js_of_ocaml

	type aceType = Ocaml_mode.editor Ace.editor

	let aceRef: aceType option ref =
		ref None

	let setAce ace =
		aceRef := Some ace

	let getAce () =
		match !aceRef with
		| None ->
			failwith "AceMixin: missed to call Learnocaml_bridge.AceMixin.setAce from the Learnocaml_exercise_main module."
		| Some ace -> 
			ace

	let debug text =
		let choice = 0 in	(* 0=OFF; 1=ALERT; 2=LOG *)
			match choice with
			| 1 -> ignore (Js.Unsafe.global##alert (Js.string text))
			| 2 -> ignore (Firebug.console##log (Js.string text))
			| _ -> ()

	let toSend () =
		let text = Ace.get_contents (getAce ()) in
			debug ("Send: " ^ text);
			text

	let receive text =
		debug ("Receive: " ^ text);
		Ace.set_contents (getAce ()) text
end

module UserInteractionMixin : sig	(* Supply a Learn-Ocaml button to the bridges needing it *)
	val setupUserInteraction : string -> (unit -> unit Lwt.t) -> unit
end
=
struct
	open Learnocaml_common
	let setupUserInteraction name action =
		let exo_toolbar = find_component "learnocaml-exo-toolbar" in
		let toolbar_button = button ~container: exo_toolbar ~theme: "light" in
			toolbar_button ~icon: "upload" name @@ fun () -> action ()
		
end


(* ---------------------------------------------------------------------------
	XBridge

	Bridge from the xtool to the main app.

	Functor that adds bridge connectivity to any web app, making it an xtool.
	The specifics of the xtool are passed on the functor parameter.
 --------------------------------------------------------------------------- *)

module XBridge(Config : BridgeConfigSig) : BridgeSig =	(* The XBridge functor *)
struct
	open Js_of_ocaml

	(* The broadcast channel reference - connects the xtool to the main app *)
	let bcRef : 'a Js_of_ocaml.Js.t option ref =
		ref None

	(* Get the broadcast channel in use *)
	let bc () =
		match !bcRef with
		| Some bc -> bc
		| None -> failwith "BC API unavailable"

	(* Callback function: Receiving a message from the main app *)
	let receive ev =
		let text = Js.to_string ev##.data in
			if text = "rendezvous"	(* check if it is the ping *)
			then MyBroadcastChannel.post (bc()) "rendezvous"	(* if so, send the reply *)
			else Config.receive text; (* otherwise, handle a regular message *)
			Js._true

	(* Sending a message to the main app *)
	let send () = 
		let text = Config.toSend () in
			MyBroadcastChannel.post (bc()) text;
			Lwt.return_unit

	(* Setup the broadcast channel object *)
	let openChannel () =
		if !bcRef = None then
			let chan = MyBroadcastChannel.create Config.channelName in
				MyBroadcastChannel.on chan receive;	(* install the callback *)
				bcRef := Some chan

	(* Sending a message, while ensuring the channel is open *)
	let safeSend () =
		openChannel ();		(* the channel is lazily opened *)
		send ()

  (* -- Setup the XBridge functor instance -- *)

	(* Setup some user interface elements in the xtool. *)
	let setup () =
		if MyBroadcastChannel.isSupported () then
			Config.setupUserInteraction "Learn-OCaml" safeSend
end

