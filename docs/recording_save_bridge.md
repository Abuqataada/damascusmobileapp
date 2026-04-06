# Save Live Recordings On Mobile

The current recording code uses:

```js
const url = URL.createObjectURL(blob);
const a = document.createElement('a');
a.href = url;
a.download = 'something.webm';
a.click();
```

That works in desktop browsers, but it is unreliable inside a mobile WebView.
The Flutter app now includes a native save bridge, so the page should send the blob
to Flutter instead of relying on a download anchor.

## Replace the `mediaRecorder.onstop` block

Use this pattern inside your Flask page:

```html
<script>
async function saveRecordingBlob(blob, fileName) {
    const reader = new FileReader();
    reader.onloadend = async () => {
        const dataUrl = reader.result; // data:video/webm;base64,...

        if (window.flutter_inappwebview && window.flutter_inappwebview.callHandler) {
            await window.flutter_inappwebview.callHandler('saveRecording', {
                name: fileName,
                data: dataUrl
            });
            toast('Recording saved to device storage', 'success');
        } else {
            const url = URL.createObjectURL(blob);
            const a = document.createElement('a');
            a.href = url;
            a.download = fileName;
            document.body.appendChild(a);
            a.click();
            document.body.removeChild(a);
            URL.revokeObjectURL(url);
        }
    };
    reader.readAsDataURL(blob);
}

mediaRecorder.onstop = () => {
    const blob = new Blob(recordedChunks, { type: 'video/webm' });
    const fileName = `live_stream_${STREAM_ID}_${new Date().toISOString().slice(0,19).replace(/:/g, '-')}.webm`;
    saveRecordingBlob(blob, fileName);
};
</script>
```

## What the app does with it

- Android: saves the file into public Movies storage so it appears in gallery/media apps
- iPhone: saves the file into the user's Photos library

## Important note

The bridge now saves to user-visible media storage, which is the best production choice for this use case.
