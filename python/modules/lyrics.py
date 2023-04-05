#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
This module provides functions and classes for accessing song lyrics.

WIP
"""

from __future__ import annotations
from abc import ABC, abstractmethod


class LyricDatabase(ABC):
    """
    An abstract base class for lyric databases.
    """

    def __init__(self, name: str):
        self.name = name
        self._cache: dict[str, str] = {}

    def get_lyrics(self, song: str, artist: str = None, album: str = None) -> str:
        """
        Gets the lyrics for a song.

        Args:
            song (str): The name of the song.
            artist (str, optional): The name of the artist. Defaults to None.
            album (str, optional): The name of the album. Defaults to None.

        Returns:
            str: The lyrics for the song.
        """
        song_id: str = f"{artist}::{album}::{song}"
        if song_id in self._cache:
            return self._cache[song_id]
        lyrics: str = self._get_lyrics(song, artist, album)

        # Cache the lyrics
        self._cache[song_id] = lyrics
        return lyrics

    @abstractmethod
    def _get_lyrics(self, song: str, artist: str = None, album: str = None) -> str:
        """
        Gets the lyrics for a song.

        Args:
            song (str): The name of the song.
            artist (str, optional): The name of the artist. Defaults to None.
            album (str, optional): The name of the album. Defaults to None.

        Returns:
            str: The lyrics for the song.
        """
        ...

    @abstractmethod
    def get_song(self, query: str) -> tuple[str, str, str]:
        """
        Gets a song from the database.

        Args:
            query (str): The query to search for.

        Returns:
            tuple[str, str, str]: A tuple containing the name of the song, the name of
                the artist, and the name of the album.
        """
        ...


class AZlyrics(LyricDatabase):
    """
    A class for accessing the AZlyrics database.
    """

    def __init__(self):
        super().__init__("AZlyrics")

    def _get_lyrics(self, song: str, artist: str = None, album: str = None) -> str:
        """
        Gets the lyrics for a song.

        Args:
            song (str): The name of the song.
            artist (str, optional): The name of the artist. Defaults to None.
            album (str, optional): The name of the album. Defaults to None.

        Returns:
            str: The lyrics for the song.
        """
