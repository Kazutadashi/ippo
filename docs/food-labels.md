# Filling in a food from its nutrition label

When you add a food (**Food › + Add food › + New food**), the form has
a **Paste nutrition label** button at the top. It reads the text of a
nutrition label and fills in the name, serving size and nutrients for
you. You can check and change everything before saving.

Ippo never goes online, so it cannot read a photo by itself. There are
three ways to get the label's text in:

1. **Type it** into the window, line by line.
2. **Copy text** from a shop's website or a food database and paste it.
3. **Take a photo and ask an assistant** (such as Claude) to write the
   label in the format below, then copy its answer and paste it.


## What Ippo understands

Ippo reads the text line by line and ignores anything it does not
recognise. It understands:

- **US-style labels:** "Serving size 9 chips (28g)", "Calories 150",
  "Total Fat 9g", "Saturated Fat 1.5g", "Sodium 170mg", "Total
  Carbohydrate 15g", "Dietary Fiber 1g", "Total Sugars 1g",
  "Protein 2g".
- **European-style labels:** "per 100 g", "Energy 2010 kJ / 480 kcal",
  "Fat 30 g", "of which saturates 3 g", "Carbohydrate 50 g", "of which
  sugars 1 g", "Fibre 4 g", "Protein 6 g", "Salt 1.2 g".
- **The simple format** below.

Details:

- If the text says "per 100 g" (or "per 100 ml"), the values are taken
  as per 100. Otherwise they are taken as per serving, and the serving
  size is needed to work out the values per 100.
- Energy in kJ only is turned into kcal (1 kcal = 4.184 kJ).
- Sodium is turned into salt (salt = sodium × 2.5) if no salt is given.
- Serving sizes can be fractions: "2/3 cup (55g)".
- Commas work as decimal marks: "3,5 g".
- Every nutrient on the label is kept, including trans fat,
  cholesterol, added sugars, minerals and vitamins (see "Nutrients" in
  `docs/data-format.md`). Amounts in mg, mcg or µg are turned into each
  nutrient's own unit. A line with only a % daily value ("Vitamin A
  10%") is skipped: it gives no amount.
- **Ingredients**: everything after "Ingredients:" up to the next empty
  line is kept as the food's ingredients.


## The simple format

One value per line, as `name: value`:

```
name: Potato chips
serving: 9 chips = 28 g
calories: 150
fat: 9 g
saturated fat: 1.5 g
carbohydrates: 15 g
sugars: 1 g
fiber: 1 g
protein: 2 g
salt: 0.4 g
cholesterol: 0 mg
vitamin d: 2 mcg
calcium: 20 mg

ingredients: Potatoes, sunflower oil, salt.
```

- `serving` is how many pieces, what they are, and what they weigh.
  For a label with only a weight, write `serving: 30 g`.
- Leave out any line the label does not have.
- Add a line `per 100 g` if the values are per 100 g instead of per
  serving.

The **Copy the format** button (under **Using a photo?** in the
window) copies an example, so you can paste it into your request to the
assistant.


## A request to give an assistant with the photo

> Read the nutrition label in this photo. Write it in exactly this
> format, one value per line, leaving out lines the label does not
> have. Use the values per serving, and keep the label's serving size
> and its weight in grams (or ml). Do not add anything else.
>
> ```
> name: …
> serving: <how many> <what> = <weight> g
> calories: …
> fat: … g
> saturated fat: … g
> carbohydrates: … g
> sugars: … g
> fiber: … g
> protein: … g
> salt: … g
> ```

If the label has only values per 100 g, ask for those and add the line
`per 100 g`.


## Entering amounts in pieces

Once a food has a serving size, logging it offers a choice between its
pieces and grams: type **9 chips** and Ippo shows "= 28 g" and the
calories; type **40 g** and it shows "≈ 12.9 chips". The entry always
stores the grams, plus the number of pieces if you typed pieces (see
`unit_count` in `docs/data-format.md`).
