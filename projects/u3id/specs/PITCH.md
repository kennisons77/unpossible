## Pitch Document
i want to bootstrap a new project called u3id it will be mostly research. it is a spec for a way to identify the concept of an object in a universal sense according to some scope. For example My iphone takes what is essentially 14 snapshots everytime I take a picture. I want a standard for iding the difference between the HEIC file and a songle image, or a thing taken from that image. I want the spec to drive a db of identified things. Markd down this idea with 5 or so suggestions for research on things like standards, nfts and uuid  efectively create the pitch document


5 research threads:
1. URN / DOI / ISCC — prior art on persistent, location-independent identity
2. Content-addressable storage (IPFS, Git) — where hashes break down for conceptual grouping
3. NFTs / ERC-1155 — what the token world got right and wrong about representing derivatives
4. RDF / OWL — the semantic web already has owl:sameAs and named graphs; can u3id just be a vocabulary?
5. HEIC internals / Apple Photos — the concrete use case that drives the whole spec

The HEIC example is the killer demo — one shutter press, 14 frames, a depth map, a Live Photo video, and a "key photo."
None of those have a standard way to say "these are all representations of the same moment." That's the gap u3id
fills.

REFINED

Think of a birthday party. It's an event of some import to a group of people. It can be represented by objects both real and digital. A present is a real world example (cash maybe?) and the evite is a digital one. The use cas e that comes to mind though, and where I think a product might be is, the classification of the images captured during or as a result of said event. The event it self might be able to be narrowed doen to a timestamp, anything else, like location, might be too abastract. I was recently copying 60,000 images from the cloud to a drive. Many of the files contain more than just a pixel image, metadata woth location or HEICs which contain (as we saw) 14 frames, a depth map, a Live Photo video, and a "key photo."
After thinking that it would be nice to identify a way to de duplicate those photos and the jpg copy of their key frame I also got to thinking that I don't need that many photos of the event. Even if I didn't I'd want to associate all that I had, not just from that shutter press, but from the entire event, which was the real PIN to reality. 

I recenlty worked scraping regulatory documents, they also are documents strongly tied to an event. A meeting is heald by a government and maybe there is some leag consequence. They don't actually contain laws, they just describe them. Different kinds of documents could be published from the same event. When scraping EVERY scrpaed version of a doc relating to said event proves a possible duplication issue. I think there is value in tieing these things together. 

The images themselves might hold some promise as one could establish a way to identify original comic art, a copy of said comic, a reprint, a scan of the cover. Associate these if its valuable, ignore em if not. 


Quick spitball of format ideas

|     __event__     | __recording/side affect__ |   __name?__   | __size?__
 timerange location    timestamp type location    hashed string     dumb?
