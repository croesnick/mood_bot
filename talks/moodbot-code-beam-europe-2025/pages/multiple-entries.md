---
title: "Multiple Entries"
level: 2
---

You can split your slides.md into multiple files and organize them as you want using the `src` attribute.

<TwoCols layoutClass="gap-12">
<template v-slot:left>

#### `slides.md`

```markdown
# Page 1

Page 2 from main entry.

---
src: ./subpage.md
---
```

</template v-slot:left>
<template v-slot:right>

#### `subpage.md`

```markdown
# Page 2

Page 2 from another file.
```

</template v-slot:right>
</TwoCols>

[Learn more](https://sli.dev/guide/syntax.html#multiple-entries)
