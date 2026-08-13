import { useIncomingShare } from 'expo-sharing';
import React, { useEffect, useMemo, useState } from 'react';
import { Alert, Pressable, ScrollView, Share, View } from 'react-native';

import { AppButton } from '@/components/app/app-button';
import { AppIcon } from '@/components/app/app-icon';
import { AppInput } from '@/components/app/app-input';
import { AppText } from '@/components/app/app-text';
import { Card } from '@/components/app/card';
import { Chip } from '@/components/app/chip';
import { radii, spacing } from '@/constants/tokens';
import { useApp } from '@/context/app-context';
import { useAppTheme } from '@/context/theme-context';

export default function NotesTab() {
  const { colors } = useAppTheme();
  const { data, addNote, updateNote, deleteNote, planNote } = useApp();
  const incoming = useIncomingShare();
  const [query, setQuery] = useState('');
  const [editingId, setEditingId] = useState<string>();
  const [title, setTitle] = useState('');
  const [body, setBody] = useState('');
  const [composing, setComposing] = useState(false);

  useEffect(() => {
    if (!incoming.sharedPayloads.length) return;
    const imported = incoming.sharedPayloads.map((payload) => payload.value).filter(Boolean);
    if (!imported.length) return;
    imported.forEach((value) => addNote('', value, 'apple-share'));
    incoming.clearSharedPayloads();
    Alert.alert('Saved from Apple Notes', `${imported.length} shared ${imported.length === 1 ? 'item is' : 'items are'} now in your private notes.`);
  }, [addNote, incoming]);

  const notes = useMemo(() => data.notes.filter((note) => {
    const needle = query.trim().toLowerCase();
    return !needle || `${note.title} ${note.body}`.toLowerCase().includes(needle);
  }), [data.notes, query]);

  function newNote() {
    setEditingId(undefined);
    setTitle('');
    setBody('');
    setComposing(true);
  }

  function edit(noteId: string) {
    const note = data.notes.find((item) => item.id === noteId);
    if (!note) return;
    setEditingId(note.id);
    setTitle(note.title);
    setBody(note.body);
    setComposing(true);
  }

  function save() {
    if (!title.trim() && !body.trim()) return;
    if (editingId) updateNote(editingId, title, body);
    else addNote(title, body);
    setComposing(false);
    setEditingId(undefined);
    setTitle('');
    setBody('');
  }

  async function shareToNotes(noteId: string) {
    const note = data.notes.find((item) => item.id === noteId);
    if (!note) return;
    await Share.share({ title: note.title, message: `${note.title}\n\n${note.body}` });
  }

  return (
    <ScrollView contentInsetAdjustmentBehavior="automatic" keyboardShouldPersistTaps="handled" contentContainerStyle={{ padding: spacing.md, paddingBottom: 120, gap: spacing.xl }}>
      <View style={{ flexDirection: 'row', alignItems: 'center', gap: spacing.md }}>
        <View style={{ flex: 1, gap: 3 }}>
          <AppText variant="title">Notes</AppText>
          <AppText variant="small" tone="secondary">Capture ideas, turn them into plan inputs, or move them through Apple’s share sheet.</AppText>
        </View>
        <Pressable onPress={newNote} style={({ pressed }) => ({ width: 50, height: 50, borderRadius: 19, borderCurve: 'continuous', backgroundColor: colors.accent, alignItems: 'center', justifyContent: 'center', opacity: pressed ? 0.72 : 1 })}>
          <AppIcon name="square.and.pencil" fallback="+" color="#FFFFFF" size={24} />
        </Pressable>
      </View>

      {composing ? (
        <Card style={{ gap: spacing.md, borderColor: colors.accent }}>
          <AppInput value={title} onChangeText={setTitle} placeholder="Note title" autoFocus />
          <AppInput
            value={body}
            onChangeText={setBody}
            placeholder="Write anything…"
            multiline
            textAlignVertical="top"
            style={{ minHeight: 190 }}
          />
          <View style={{ flexDirection: 'row', gap: spacing.sm }}>
            <AppButton title="Cancel" variant="secondary" onPress={() => setComposing(false)} style={{ flex: 1 }} />
            <AppButton title={editingId ? 'Save changes' : 'Save note'} onPress={save} style={{ flex: 2 }} />
          </View>
        </Card>
      ) : null}

      <Card muted style={{ gap: spacing.md }}>
        <View style={{ flexDirection: 'row', alignItems: 'center', gap: spacing.md }}>
          <View style={{ width: 48, height: 48, borderRadius: 18, backgroundColor: colors.warningSoft, alignItems: 'center', justifyContent: 'center' }}>
            <AppIcon name="square.and.arrow.down" fallback="↓" color={colors.warning} size={23} />
          </View>
          <View style={{ flex: 1 }}>
            <AppText variant="heading">Apple Notes bridge</AppText>
            <AppText variant="small" tone="secondary">In Apple Notes, tap Share, then choose AI Plan Your Day. To send a note back, use “Share” below and choose Notes.</AppText>
          </View>
        </View>
        <AppText variant="caption" tone="tertiary">Apple does not provide third-party apps full database access to Apple Notes, so the system Share Sheet is the private, official handoff.</AppText>
      </Card>

      <AppInput value={query} onChangeText={setQuery} placeholder="Search notes" />

      <View style={{ gap: spacing.sm }}>
        {notes.map((note) => (
          <Pressable key={note.id} onPress={() => edit(note.id)}>
            <Card style={{ gap: spacing.sm }}>
              <View style={{ flexDirection: 'row', gap: spacing.sm, alignItems: 'flex-start' }}>
                <View style={{ width: 42, height: 42, borderRadius: 16, backgroundColor: note.source === 'apple-share' ? colors.warningSoft : colors.accentSoft, alignItems: 'center', justifyContent: 'center' }}>
                  <AppIcon name={note.source === 'apple-share' ? 'apple.logo' : 'note.text'} fallback="≡" color={note.source === 'apple-share' ? colors.warning : colors.accent} size={21} />
                </View>
                <View style={{ flex: 1, gap: 4 }}>
                  <View style={{ flexDirection: 'row', alignItems: 'center', gap: spacing.xs }}>
                    <AppText variant="heading" numberOfLines={1} style={{ flex: 1 }}>{note.title}</AppText>
                    {note.source === 'apple-share' ? <Chip label="APPLE" selected color={colors.warning} /> : null}
                  </View>
                  <AppText variant="small" tone="secondary" numberOfLines={3}>{note.body || 'Empty note'}</AppText>
                  <AppText variant="caption" tone="tertiary">Edited {new Date(note.updatedAt).toLocaleDateString()}</AppText>
                </View>
              </View>
              <View style={{ flexDirection: 'row', gap: spacing.sm }}>
                <AppButton compact title="Add to Inbox" onPress={() => {
                  planNote(note.id);
                  Alert.alert('Added to Inbox', 'The note is ready for AI scheduling.');
                }} style={{ flex: 1 }} />
                <AppButton compact title="Share" variant="secondary" onPress={() => void shareToNotes(note.id)} style={{ flex: 1 }} />
                <Pressable
                  accessibilityLabel="Delete note"
                  onPress={() => Alert.alert('Delete this note?', note.title, [
                    { text: 'Cancel', style: 'cancel' },
                    { text: 'Delete', style: 'destructive', onPress: () => deleteNote(note.id) },
                  ])}
                  style={({ pressed }) => ({ width: 42, height: 42, borderRadius: 16, alignItems: 'center', justifyContent: 'center', backgroundColor: colors.surfaceMuted, opacity: pressed ? 0.7 : 1 })}>
                  <AppIcon name="trash" fallback="×" color={colors.textTertiary} size={18} />
                </Pressable>
              </View>
            </Card>
          </Pressable>
        ))}
        {!notes.length ? (
          <View style={{ minHeight: 220, borderRadius: radii.xl, borderCurve: 'continuous', backgroundColor: colors.surface, borderWidth: 1, borderColor: colors.border, alignItems: 'center', justifyContent: 'center', gap: spacing.sm }}>
            <AppIcon name="note.text.badge.plus" fallback="+" color={colors.textTertiary} size={34} />
            <AppText variant="heading">Your note space is open</AppText>
            <AppText variant="small" tone="secondary">Write here or share a note from Apple Notes.</AppText>
            <AppButton compact title="Create a note" onPress={newNote} />
          </View>
        ) : null}
      </View>
    </ScrollView>
  );
}
