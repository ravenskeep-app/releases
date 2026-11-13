# RavensKeep releases

Prebuilt components that RavensKeep downloads when you turn on an optional feature. You don't
need to download anything here by hand: the app fetches the exact file it needs and checks it
against a SHA-256 hash built into the app before unpacking it.

## whisper.cpp (Vulkan) for Windows

`whispercpp-v<version>` releases hold [whisper.cpp](https://github.com/ggml-org/whisper.cpp)'s
`whisper-server`, built with the Vulkan backend so speech transcription runs on AMD, Intel or
NVIDIA graphics cards. RavensKeep downloads it when you press **Install whisper.cpp** in
**Settings → AI → Transcription Model**.

Each build is made by [this repo's workflow](.github/workflows/whispercpp.yml) from the upstream
whisper.cpp tag, using [tools/build_whispercpp_vulkan.ps1](tools/build_whispercpp_vulkan.ps1).
The build is portable: no processor-specific optimisations and the C++ runtime linked in, so it
needs only a graphics driver with Vulkan, which current AMD, Intel and NVIDIA drivers include.

To check that a zip came from this repository's workflow:

```
gh attestation verify whispercpp-vulkan-<version>-win-x64.zip -R ravenskeep-app/releases
```

whisper.cpp is MIT licensed; its license is included in each zip as `LICENSE-whisper.cpp.txt`.

## Making a new whisper.cpp release

1. **Actions → whisper.cpp (Vulkan, Windows x64) → Run workflow**, with the upstream tag (for
   example `v1.9.5`). Leave **build** at `1` unless that version already has a published
   release; a rebuild with build `2` is released as `whispercpp-v1.9.5-b2`.
2. The run saves a **draft** release and prints the version and SHA-256 in its summary. Download
   the zip from the draft and test it in the app. Running the workflow again for the same
   version replaces the draft's files.
3. Publish the draft, then pin the version and SHA-256 from the summary in the app's
   `buildVersion` and `buildSha256`.

Never edit, replace or delete a published release: installed copies of the app download it by
its exact name and hash.
