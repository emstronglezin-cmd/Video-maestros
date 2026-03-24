import { Firestore } from 'firebase-admin/firestore';
import { getFirestore } from 'firebase-admin/firestore';
import { z } from 'zod';

/**
 * Schéma de validation utilisateur
 */
export const UserSchema = z.object({
  uid: z.string().min(1),
  email: z.string().email(),
  username: z.string().min(3).max(30).regex(/^[a-zA-Z0-9_]+$/),
  displayName: z.string().optional(),
  photoURL: z.string().url().optional(),
  createdAt: z.date().or(z.string()),
  updatedAt: z.date().or(z.string()),
  isPremium: z.boolean().default(false),
  videosCreated: z.number().default(0),
  storageUsed: z.number().default(0), // en bytes
});

export type User = z.infer<typeof UserSchema>;

/**
 * Interface pour la création d'utilisateur
 */
export interface CreateUserInput {
  uid: string;
  email: string;
  username: string;
  displayName?: string;
  photoURL?: string;
}

/**
 * Interface pour mise à jour utilisateur
 */
export interface UpdateUserInput {
  username?: string;
  displayName?: string;
  photoURL?: string;
}

/**
 * Modèle de gestion des utilisateurs dans Firestore
 */
export class UserModel {
  private db: Firestore;
  private collection: string = 'users';

  constructor() {
    this.db = getFirestore();
  }

  /**
   * Crée un nouvel utilisateur
   */
  async create(input: CreateUserInput): Promise<User> {
    // Vérifier si le username est déjà pris
    const existingUsername = await this.findByUsername(input.username);
    if (existingUsername) {
      throw new Error('Username already taken');
    }

    // Vérifier si l'utilisateur existe déjà
    const existingUser = await this.findById(input.uid);
    if (existingUser) {
      throw new Error('User already exists');
    }

    const now = new Date();
    const userData: User = {
      uid: input.uid,
      email: input.email,
      username: input.username,
      displayName: input.displayName,
      photoURL: input.photoURL,
      createdAt: now,
      updatedAt: now,
      isPremium: false,
      videosCreated: 0,
      storageUsed: 0,
    };

    await this.db.collection(this.collection).doc(input.uid).set(userData);
    return userData;
  }

  /**
   * Trouve un utilisateur par ID
   */
  async findById(uid: string): Promise<User | null> {
    const doc = await this.db.collection(this.collection).doc(uid).get();
    if (!doc.exists) {
      return null;
    }
    return doc.data() as User;
  }

  /**
   * Trouve un utilisateur par username
   */
  async findByUsername(username: string): Promise<User | null> {
    const snapshot = await this.db
      .collection(this.collection)
      .where('username', '==', username)
      .limit(1)
      .get();

    if (snapshot.empty) {
      return null;
    }

    return snapshot.docs[0].data() as User;
  }

  /**
   * Vérifie si un username est disponible
   */
  async isUsernameAvailable(username: string): Promise<boolean> {
    const user = await this.findByUsername(username);
    return user === null;
  }

  /**
   * Met à jour un utilisateur
   */
  async update(uid: string, input: UpdateUserInput): Promise<User> {
    const user = await this.findById(uid);
    if (!user) {
      throw new Error('User not found');
    }

    // Si le username change, vérifier la disponibilité
    if (input.username && input.username !== user.username) {
      const isAvailable = await this.isUsernameAvailable(input.username);
      if (!isAvailable) {
        throw new Error('Username already taken');
      }
    }

    const updateData = {
      ...input,
      updatedAt: new Date(),
    };

    await this.db.collection(this.collection).doc(uid).update(updateData);

    return await this.findById(uid) as User;
  }

  /**
   * Incrémente le compteur de vidéos créées
   */
  async incrementVideosCreated(uid: string): Promise<void> {
    await this.db.collection(this.collection).doc(uid).update({
      videosCreated: (await this.findById(uid))!.videosCreated + 1,
      updatedAt: new Date(),
    });
  }

  /**
   * Met à jour l'espace de stockage utilisé
   */
  async updateStorageUsed(uid: string, bytes: number): Promise<void> {
    await this.db.collection(this.collection).doc(uid).update({
      storageUsed: (await this.findById(uid))!.storageUsed + bytes,
      updatedAt: new Date(),
    });
  }

  /**
   * Supprime un utilisateur
   */
  async delete(uid: string): Promise<void> {
    await this.db.collection(this.collection).doc(uid).delete();
  }
}
