package main

import (
	"bufio"
	"encoding/json"
	"errors"
	"flag"
	"fmt"
	"io"
	"os"
	"regexp"
	"sort"
	"strings"
	"time"

	"fyne.io/fyne/v2"
	"fyne.io/fyne/v2/app"
	"fyne.io/fyne/v2/canvas"
	"fyne.io/fyne/v2/container"
	"fyne.io/fyne/v2/theme"
	"fyne.io/fyne/v2/widget"
)

func main() {
	rootTableFile := flag.String("root-table", "roots.tsv", "root table file, root to code")
	codeTableFile := flag.String("code-table", "mabiao.tsv", "code table file, character or word to code")
	chaifenTableFile := flag.String("chaifen-table", "chaifen.tsv", "chaifen table file, character to roots")
	wordTableFile := flag.String("word-table", "", "word table file, one word per line, default to code table")
	stateFile := flag.String("state-file", "state.json", "state of practice progress")
	nextFrom := flag.Int("next-from", 0, "Which word in word table to start, 0 means unspecified")

	flag.Parse()

	rootTable, err := readKVTable(*rootTableFile)
	if err != nil {
		fmt.Printf("Failed to read root table `%s`: %s\n", *rootTableFile, err)
		return
	}
	normalizeRootTable(rootTable)

	codeTable, err := readKVTable(*codeTableFile)
	if err != nil {
		fmt.Printf("Failed to read code table `%s`: %s\n", *codeTableFile, err)
		return
	}
	normalizeCodeTable(codeTable)

	chaifenTable, err := readKVTable(*chaifenTableFile)
	if err != nil {
		fmt.Printf("Failed to read chaifen table `%s`: %s\n", *chaifenTableFile, err)
		return
	}

	if *wordTableFile == "" {
		wordTableFile = codeTableFile
	}

	wordTable, err := readWordTable(*wordTableFile, codeTable)
	if err != nil {
		fmt.Printf("Failed to read word table `%s`: %s\n", *wordTableFile, err)
		return
	}

	fmt.Printf("%d roots, %d codes, %d chaifens, %d words\n",
		len(rootTable), len(codeTable), len(chaifenTable), len(wordTable))

	if len(wordTable) == 0 {
		fmt.Println("Empty word table!")
		return
	}

	typerState, err := loadState(*stateFile)
	if err != nil {
		fmt.Printf("Failed to read state '%s': %s\n", *stateFile, err)
		return
	}

	if *nextFrom > 0 {
		typerState.Next = *nextFrom - 1
	}
	if typerState.Next < 0 || typerState.Next >= len(wordTable) {
		typerState.Next = 0
	}

	a := app.New()
	w := a.NewWindow("形码输入法打字练习")

	w.Resize(fyne.NewSize(400, 300))

	counterLabel := widget.NewLabel("")
	wordLabel := canvas.NewText("", theme.ForegroundColor())
	inputEntry := widget.NewEntry()
	codeLabel := widget.NewLabel("")
	chaifenLabel := widget.NewLabel("")

	updateUI(counterLabel, wordLabel, codeLabel, chaifenLabel,
		rootTable, codeTable, chaifenTable, wordTable, typerState)

	counterLabel.Alignment = fyne.TextAlignTrailing
	wordLabel.Alignment = fyne.TextAlignCenter
	wordLabel.TextSize = wordLabel.TextSize * 4.0
	inputEntry.SetPlaceHolder("输入编码或者字词，按回车键跳到下一条")

	inputEntry.OnSubmitted = func(text string) {
		typerState.Next++
		if typerState.Next >= len(wordTable) {
			typerState.Next = 0
		}

		updateUI(counterLabel, wordLabel, codeLabel, chaifenLabel,
			rootTable, codeTable, chaifenTable, wordTable, typerState)

		inputEntry.SetText("")
	}

	inputEntry.OnChanged = func(text string) {
		word := wordTable[typerState.Next]
		correct := word == text
		if !correct {
			for _, code := range codeTable[word] {
				if code == text {
					correct = true
					break
				}
			}
		}

		if correct {
			wordState := typerState.Words[word]
			if wordState == nil {
				wordState = &WordState{}
				typerState.Words[word] = wordState
			}

			wordState.Count++
			wordState.Time = time.Now()
			inputEntry.OnSubmitted(text)
		}
	}

	content := container.NewVBox(
		counterLabel,
		wordLabel,
		inputEntry,
		codeLabel,
		chaifenLabel)

	w.SetContent(content)
	w.ShowAndRun()

	if err = saveState(*stateFile, typerState); err != nil {
		fmt.Printf("Failed to write state '%s': %s\n", *stateFile, err)
		return
	}
}

func readKVTable(tableFile string) (map[string][]string, error) {
	table := make(map[string][]string)

	err := readTsv(tableFile, func(fields []string, line string) error {
		if len(fields) < 2 {
			fmt.Printf("Invalid line, expected at least two columns: %s\n", line)
		} else {
			if table[fields[0]] != nil {
				found := false
				for _, f := range table[fields[0]] {
					if f == fields[1] {
						found = true
						break
					}
				}
				if found {
					return nil
				}
			}

			table[fields[0]] = append(table[fields[0]], fields[1])
		}

		return nil
	})

	if err != nil {
		return nil, err
	}

	return table, nil
}

func readWordTable(wordTableFile string, codeTable map[string][]string) ([]string, error) {
	var table []string

	err := readTsv(wordTableFile, func(fields []string, line string) error {
		if codeTable[fields[0]] == nil {
			fmt.Printf("word %s not found in code table, ignored it!\n", fields[0])
		} else {
			table = append(table, fields[0])
		}
		return nil
	})

	if err != nil {
		return nil, err
	}

	return table, err
}

func normalizeRootTable(rootTable map[string][]string) {
	for _, roots := range rootTable {
		for i, _ := range roots {
			root := roots[i]
			roots[i] = strings.ToUpper(string(root[0])) + strings.ToLower(root[1:])
		}
	}
}

func normalizeCodeTable(codeTable map[string][]string) {
	for _, codes := range codeTable {
		sort.Strings(codes)
	}
}

func readTsv(filePath string, mapper func([]string, string) error) error {
	fmt.Printf("Reading %s ...\n", filePath)

	fh, err := os.Open(filePath)
	if err != nil {
		return err
	}
	defer fh.Close()

	reader := bufio.NewReader(fh)

	for {
		line, err := reader.ReadString('\n')
		if err != nil {
			if err == io.EOF {
				break
			} else {
				return err
			}
		}

		line = strings.Trim(line, " \t\r\n")
		if len(line) == 0 || strings.HasPrefix(line, "#") {
			continue
		}

		fields := strings.FieldsFunc(line, func(c rune) bool {
			return c == ' ' || c == '\t'
		})

		err = mapper(fields, line)
		if err != nil {
			return err
		}
	}

	return nil
}

type TyperState struct {
	Next  int
	Words map[string]*WordState
}

type WordState struct {
	Count uint
	Time  time.Time
}

func loadState(stateFile string) (*TyperState, error) {
	content, err := os.ReadFile(stateFile)
	if err != nil {
		if errors.Is(err, os.ErrNotExist) {
			return &TyperState{
				Next:  0,
				Words: make(map[string]*WordState),
			}, nil
		} else {
			return nil, err
		}
	}

	var state TyperState
	err = json.Unmarshal(content, &state)
	if err != nil {
		return nil, err
	}

	if state.Words == nil {
		state.Words = make(map[string]*WordState)
	}

	return &state, nil
}

func saveState(stateFile string, state *TyperState) error {
	content, err := json.MarshalIndent(state, "", "  ")
	if err != nil {
		return err
	}

	err = os.WriteFile(stateFile, content, 0644)
	if err != nil {
		return err
	}

	return nil
}

func updateUI(counterLabel *widget.Label, wordLabel *canvas.Text,
	codeLabel, chaifenLabel *widget.Label,
	rootTable, codeTable, chaifenTable map[string][]string,
	wordTable []string, typerState *TyperState) {
	counterLabel.SetText(fmt.Sprintf("%d/%d", typerState.Next+1, len(wordTable)))

	word := wordTable[typerState.Next]
	wordLabel.Text = word
	wordLabel.Refresh()

	var b strings.Builder

	for _, code := range codeTable[word] {
		if b.Len() > 0 {
			b.WriteByte(' ')
		}
		b.WriteString(code)
	}
	codeLabel.SetText(b.String())
	b.Reset()

	r := regexp.MustCompile("(?:{[^}]+})|.")

	for _, c := range word {
		fmt.Fprintf(&b, "%c:    ", c)

		if chaifenTable[string(c)] == nil {
			b.WriteString("????\n")
			continue
		}

		for i, chaifen := range chaifenTable[string(c)] {
			if i > 0 {
				b.WriteString(" / ")
			}

			roots := r.FindAllString(chaifen, -1)

			for j, root := range roots {
				if j > 0 {
					b.WriteString("    ")
				}

				b.WriteString(root)
				b.WriteByte(' ')
				if rootTable[root] != nil {
					b.WriteString(strings.Join(rootTable[root], ","))
				}
			}
		}

		b.WriteByte('\n')
	}
	chaifenLabel.SetText(b.String())
}
